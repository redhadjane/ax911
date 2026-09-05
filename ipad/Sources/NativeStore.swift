import Foundation
import Combine

struct NativeFailure: LocalizedError {
    var status:Int; var message:String; var payload:J = .null
    var errorDescription:String? { message }
}
private final class NativeRedirectGuard:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) { completionHandler(nil) }
}
@MainActor final class NativeAPI {
    let credentials=ManagerSession()
    private let guardDelegate=NativeRedirectGuard()
    private lazy var session:URLSession = {
        let c=URLSessionConfiguration.ephemeral; c.urlCache=nil; c.httpCookieStorage=nil; c.httpShouldSetCookies=false
        c.timeoutIntervalForRequest=25; c.timeoutIntervalForResource=45
        return URLSession(configuration:c,delegate:guardDelegate,delegateQueue:nil)
    }()
    func request(_ path:String,method:String="GET",body:J?=nil) async throws -> J {
        guard let url=CommandPolicy.apiURL(CommandPolicy.origin+path,method:method) else { throw NativeFailure(status:0,message:"This HOP address is not allowed.") }
        let token=credentials.token
        var request=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData); request.httpMethod=method
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        if let token,path != "/api/command-auth/login" { request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization") }
        if let body { request.httpBody=try JSONEncoder().encode(body); request.setValue("application/json",forHTTPHeaderField:"Content-Type") }
        let(data,response)=try await session.data(for:request)
        guard let http=response as? HTTPURLResponse else { throw NativeFailure(status:0,message:"The server did not return a response.") }
        let payload=(try? JSONDecoder().decode(J.self,from:data)) ?? .null
        guard (200...299).contains(http.statusCode) else {
            let detail=payload.first("user_message","error","message")
            throw NativeFailure(status:http.statusCode,message:detail.isEmpty ? "HOP returned HTTP \(http.statusCode). Please try again." : detail,payload:payload)
        }
        if payload["database_available"] == .bool(false) { throw NativeFailure(status:503,message:"The server cannot reach the database. No changes have been saved.",payload:payload) }
        if path == "/api/command-auth/login" { try credentials.save(payload["access_token"].text) }
        return payload
    }
}

enum NativeModule:String,CaseIterable,Identifiable {
    case home,schedule,employees,inbox,applications,website,menu,hopclub,availability,tasks,parties,invoices,reports,notifications,settings,watchdog
    var id:String { rawValue }
    var title:String { switch self { case .home:return "Command Center"; case .hopclub:return "HOP Club"; case .watchdog:return "HOP Watchdog"; default:return rawValue.capitalized } }
    var icon:String { switch self { case .home:return "square.grid.2x2"; case .schedule:return "calendar"; case .employees:return "person.2"; case .inbox:return "tray"; case .applications:return "person.crop.rectangle.badge.plus"; case .website:return "globe"; case .menu:return "fork.knife"; case .hopclub:return "gift"; case .availability:return "calendar.badge.clock"; case .tasks:return "checklist"; case .parties:return "party.popper"; case .invoices:return "doc.text"; case .reports:return "chart.bar.xaxis"; case .notifications:return "bell"; case .settings:return "gearshape"; case .watchdog:return "waveform.path.ecg" } }
}
@MainActor final class NativeStore:ObservableObject {
    let api=NativeAPI()
    @Published var module:NativeModule = .home
    @Published var manager:J = .null
    @Published var signedIn=false
    @Published var restoring=true
    @Published var loading=false
    @Published var saving=false
    @Published var error:String?
    @Published var notice:String?
    @Published var data:[String:J]=[:]
    @Published var failures:[String:String]=[:]
    @Published var week=HOPDay.week(HOPDay.today)
    @Published var selected:J?
    @Published var theme="system"
    @Published var lastSync:Date?
    private var generation=0
    var employees:[J] { items("/api/employees","employees") }
    var notifications:[J] { items("/api/notifications/manager","notifications") }
    var unread:Int { notifications.filter { $0["read_at"].isNull && !$0["read"].truth }.count }
    func items(_ path:String,_ keys:String...) -> [J] { let value=data[path] ?? .null; if case .array = value { return value.array }; for key in keys { if case .array = value[key] { return value[key].array } }; return [] }
    func name(_ id:String) -> String { employees.first { $0.id == id }?.first("display_name","name","full_name") ?? "Unknown employee" }
    var schedules:[J] { items("/api/schedules?week_start_date=\(week)","schedules") }
    func schedule(_ mode:String) -> J { schedules.filter { $0["status"].text == mode }.sorted { $0["version_number"].int > $1["version_number"].int }.first ?? .null }
    var available:[J] { items("/api/availability?week_start=\(week)","availability") }
    func paths(for module:NativeModule) -> [String] {
        let board="/api/schedules?week_start_date=\(week)", availability="/api/availability?week_start=\(week)", parties="/api/parties?from=\(week)&to=\(HOPDay.add(week,20))"
        switch module {
        case .home:return [board,"/api/employees",availability,parties,"/api/command/summary","/api/invoices","/api/notifications/manager","/api/inbox/pending"]
        case .schedule:return [board,"/api/employees",availability,parties]
        case .employees,.availability:return ["/api/employees",board,availability]
        case .inbox:return ["/api/inbox/pending","/api/inbox/history","/api/employees"]
        case .applications:return ["/api/job-applications"]
        case .website:return ["/api/website-content","/api/media/library?target=homepage_hero"]
        case .menu:return ["/api/menu/items","/api/menu/categories","/api/media/library?target=menu_item_image"]
        case .hopclub:return ["/api/hopclub/admin/dashboard","/api/hopclub/admin/customers","/api/hopclub/admin/reward-rules","/api/hopclub/campaigns","/api/media/library?target=reward_image"]
        case .tasks:return ["/api/tasks",board,"/api/employees"]
        case .parties:return ["/api/parties?from=\(HOPDay.add(week,-40))&to=\(HOPDay.add(week,80))","/api/employees"]
        case .invoices:return ["/api/invoices","/api/menu/items","/api/menu/categories","/api/command/v2/catering"]
        case .reports:return ["/api/employees",board,"/api/invoices",parties]
        case .notifications:return ["/api/notifications/manager","/api/employees","/api/push/status-summary"]
        case .settings:return ["/api/settings","/api/print-center/status"]
        case .watchdog:return ["/api/command/v2/watchdog"]
        }
    }
    func restore() async {
        defer { restoring=false }
        guard api.credentials.token != nil else { return }
        do { let result=try await api.request("/api/command-auth/session"); manager=result["manager"]; signedIn=true; await load() }
        catch { self.error=error.localizedDescription; if (error as? NativeFailure)?.status == 401 { api.credentials.clear() } }
    }
    func login(name:String,pin:String) async {
        saving=true; defer { saving=false }
        do { let result=try await api.request("/api/command-auth/login",method:"POST",body:.object(["name":.s(name),"pin":.s(pin)])); manager=result["manager"]; signedIn=true; error=nil; await load() }
        catch { self.error=error.localizedDescription }
    }
    func logout() { generation += 1; api.credentials.clear(); manager = .null; signedIn=false; data=[:]; failures=[:]; selected=nil; lastSync=nil }
    func load(extra:[String]=[]) async {
        guard signedIn else { return }; let ticket=generation; loading=true
        let paths=Array(Set(paths(for:module)+extra))
        await withTaskGroup(of:(String,J?,String?,Int).self) { group in
            for path in paths { group.addTask { [api] in do { return (path,try await api.request(path),nil,200) } catch { return (path,nil,error.localizedDescription,(error as? NativeFailure)?.status ?? 0) } } }
            for await (path,value,detail,status) in group {
                guard ticket == generation else { continue }
                if status == 401 { logout(); error="Your manager session expired. Please sign in again."; continue }
                if let value { data[path]=value; failures[path]=nil } else { failures[path]=detail }
            }
        }
        loading=false; if ticket == generation { lastSync=Date() }
    }
    @discardableResult func send(_ path:String,method:String="POST",body:J = .object([:]),success:String="Saved") async throws -> J {
        guard !saving else { throw NativeFailure(status:0,message:"Another change is still saving.") }
        saving=true; defer { saving=false }
        do { let value=try await api.request(path,method:method,body:body); notice=success; return value }
        catch { if (error as? NativeFailure)?.status == 401 { logout() }; throw error }
    }
    func report(_ error:Error) { self.error=error.localizedDescription }
}
