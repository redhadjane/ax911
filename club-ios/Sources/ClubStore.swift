import Foundation
import Combine

struct ClubFailure:LocalizedError {var status:Int;var message:String;var errorDescription:String?{message}}
private final class ClubRedirectGuard:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
}
@MainActor final class ClubAPI {
    let vault=ClubSession()
    private let redirect=ClubRedirectGuard()
    private lazy var session:URLSession={let c=URLSessionConfiguration.ephemeral;c.httpShouldSetCookies=false;c.httpCookieStorage=nil;c.urlCache=nil;c.timeoutIntervalForRequest=25;c.timeoutIntervalForResource=45;return URLSession(configuration:c,delegate:redirect,delegateQueue:nil)}()
    func raw(_ path:String,method:String="GET",body:J?=nil,key:String?=nil) async throws -> Data {
        guard let url=ClubPolicy.url(path,method:method) else {throw ClubFailure(status:0,message:"This action is not available in the customer app.")}
        var request=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData);request.httpMethod=method
        request.setValue(path.hasSuffix("qr") ? "image/svg+xml" : "application/json",forHTTPHeaderField:"Accept")
        if !ClubPolicy.publicReads.contains(path),path != "/api/hopclub/v2/login" {guard let token=vault.token else{throw ClubFailure(status:401,message:"Sign in to your HOP Club account.")};request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")}
        if let body {request.httpBody=try JSONEncoder().encode(body);request.setValue("application/json",forHTTPHeaderField:"Content-Type")}
        if let key {request.setValue(key,forHTTPHeaderField:"Idempotency-Key")}
        let (data,response)=try await session.data(for:request)
        guard let http=response as? HTTPURLResponse else{throw ClubFailure(status:0,message:"No response from HOP. Please try again.")}
        guard (200...299).contains(http.statusCode) else{let payload=(try? JSONDecoder().decode(J.self,from:data)) ?? .null;throw ClubFailure(status:http.statusCode,message:payload.first("user_message","error","message").isEmpty ? "HOP returned HTTP \(http.statusCode). Please try again." : payload.first("user_message","error","message"))}
        return data
    }
    func get(_ path:String,method:String="GET",body:J?=nil,key:String?=nil) async throws -> J {
        let data=try await raw(path,method:method,body:body,key:key)
        guard let value=try? JSONDecoder().decode(J.self,from:data),!value.isNull else{throw ClubFailure(status:0,message:"HOP returned incomplete data. Please refresh.")};return value
    }
}
@MainActor final class ClubStore:ObservableObject {
    let api=ClubAPI()
    @Published var bundle:J = .null
    @Published var menu:J = .null
    @Published var website:J = .null
    @Published var config:J = .null
    @Published var restoring=true
    @Published var loading=false
    @Published var busy=false
    @Published var error:String?
    @Published var notice:String?
    @Published var tab="home"
    @Published var cart:[J]=[]
    @Published var pending:J?
    @Published var lastSync:Date?
    private var generation=0
    var customer:J {bundle["customer"]}
    var loyalty:J {bundle["loyalty"]}
    var signedIn:Bool {!customer.id.isEmpty}
    var rewards:[J] {loyalty["rewards"].array}
    var orders:[J] {bundle["orders"].array}
    var ordering:Bool {config["enabled"].truth && config["ordering_enabled"].truth && bundle["feature"]["ordering_enabled"].truth}
    func restore() async {defer {restoring=false};guard api.vault.token != nil else{return};await refresh()}
    func login(username:String,pin:String) async {
        guard !busy else{return};busy=true;defer {busy=false}
        do {let result=try await api.get("/api/hopclub/v2/login",method:"POST",body:.object(["username":.s(username),"pin":.s(pin)]));guard result["experience"].text == "v2",!result["access_token"].text.isEmpty else{throw ClubFailure(status:0,message:"This account is not enabled for the connected HOP Club experience.")};try api.vault.save(result["access_token"].text);await refresh()}
        catch {report(error)}
    }
    func refresh() async {
        guard !loading else{return};loading=true;let ticket=generation;defer {loading=false}
        do {let value=try await api.get("/api/hopclub/v2/me");guard !value["customer"].id.isEmpty else{throw ClubFailure(status:0,message:"Your member profile did not load.")};guard ticket == generation else{return};bundle=value;pending=api.vault.pending(customer.id);lastSync=Date()}
        catch {if ticket == generation {report(error)};return}
        await withTaskGroup(of:(String,J?).self) {group in
            for path in ClubPolicy.publicReads {group.addTask {[api] in (path,try? await api.get(path))}}
            for await (path,value) in group {guard ticket == generation else{continue};if let value {switch path {case "/api/hopclub/menu":menu=value;case "/api/hopclub/v2/config":config=value;default:website=value}}else{notice="Some menu or offer information could not refresh. Pull down to retry."}}
        }
    }
    func logout() {generation += 1;api.vault.clear();bundle = .null;cart=[];pending=nil;lastSync=nil;tab="home";notice=nil;busy=false}
    func report(_ failure:Error) {if (failure as? ClubFailure)?.status == 401 {logout()};error=failure.localizedDescription}
    func quote(tip:Double) async throws -> J {
        guard ordering,!cart.isEmpty else{throw ClubFailure(status:0,message:"Pickup ordering is not currently available.")}
        let result=try await api.get("/api/hopclub/v2/orders/quote",method:"POST",body:.object(["fulfillment_type":.s("pickup"),"tip":.number(tip),"items":.array(ClubMenuRules.requestItems(cart))]))
        guard !result["pricing"]["pricing_token"].text.isEmpty else{throw ClubFailure(status:0,message:"A current price quote is required before ordering.")};return result["pricing"]
    }
    func place(_ body:J) async {
        guard !busy else{return};busy=true;defer {busy=false}
        do {
            let owner=customer.id
            let request=pending ?? .object(["kind":.s("order"),"key":.s(UUID().uuidString),"body":body])
            guard request["kind"].text == "order" else{throw ClubFailure(status:0,message:"Resolve the pending reward request before placing an order.")}
            try api.vault.savePending(request,owner:owner);pending=request
            let result=try await api.get("/api/hopclub/v2/orders",method:"POST",body:request["body"],key:request["key"].text)
            guard !result["order"].id.isEmpty else{throw ClubFailure(status:0,message:"The order response was incomplete. Check order history before trying again.")}
            try api.vault.savePending(nil,owner:owner);pending=nil;cart=[];notice="Pickup request received. A host must confirm it by phone before it goes to the kitchen.";await refresh()
        }catch {report(error)}
    }
    func redeem(_ reward:J) async -> J? {
        guard !busy else{return nil};busy=true;defer {busy=false}
        do {
            let request=pending ?? .object(["kind":.s("reward"),"key":.s(UUID().uuidString),"body":.object(["reward_rule_id":.s(reward.id)])])
            guard request["kind"].text == "reward",request["body"]["reward_rule_id"].text == reward.id else{throw ClubFailure(status:0,message:"Resolve your earlier request in Account before starting another.")}
            let owner=customer.id;try api.vault.savePending(request,owner:owner);pending=request
            let result=try await api.get("/api/hopclub/v2/redemptions",method:"POST",body:request["body"],key:request["key"].text)
            guard !result["redemption"].id.isEmpty else{throw ClubFailure(status:0,message:"The reward response was incomplete. Check your requests before retrying.")}
            try api.vault.savePending(nil,owner:owner);pending=nil;await refresh();return result["redemption"]
        }catch {report(error);return nil}
    }
    func clearPendingAfterReview() {do {try api.vault.savePending(nil,owner:customer.id);pending=nil}catch{report(error)}}
}
