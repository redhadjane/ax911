import XCTest
import CoreGraphics
import Vision
@testable import ClubCore

final class QRRoundTripTests:XCTestCase {
    func testNativeModuleRenderingDecodesToOriginalPayload() throws {
        let url=try XCTUnwrap(Bundle.module.url(forResource:"qr-fixture",withExtension:"svg"))
        let qr=try XCTUnwrap(ClubQR.parse(Data(contentsOf:url)))
        let scale=10,edge=Int(qr.dimension)*scale
        let context=try XCTUnwrap(CGContext(data:nil,width:edge,height:edge,bitsPerComponent:8,bytesPerRow:edge*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray:1,alpha:1));context.fill(CGRect(x:0,y:0,width:edge,height:edge));context.setShouldAntialias(false);context.setFillColor(CGColor(gray:0,alpha:1))
        for run in qr.runs {context.fill(CGRect(x:run.x*Double(scale),y:Double(edge)-(run.y+1)*Double(scale),width:run.width*Double(scale),height:Double(scale)))}
        let image=try XCTUnwrap(context.makeImage())
        let request=VNDetectBarcodesRequest();request.symbologies=[.qr];request.usesCPUOnly=true
        try VNImageRequestHandler(cgImage:image,options:[:]).perform([request])
        XCTAssertEqual(request.results?.first?.payloadStringValue,"HOP-CLUB-NATIVE-QR-TEST")
    }
}
