//
//  RxAlamofireTests.swift
//  RxAlamofireTests
//
//  Created by Junior B. on 23/08/15.
//  Copyright © 2015 Bonto.ch. All rights reserved.
//

import XCTest
import RxSwift
import RxCocoa
import RxBlocking
import Alamofire
import OHHTTPStubs
import RxAlamofire

@testable import Alamofire

private struct Dummy {
	static let DataStringContent = "Hello World"
	static let DataStringData = DataStringContent.data(using: String.Encoding.utf8)!
	static let DataJSONContent = "{\"hello\":\"world\", \"foo\":\"bar\", \"zero\": 0}"
	static let DataJSON = DataJSONContent.data(using: String.Encoding.utf8)!
	static let GithubURL = "http://github.com/RxSwiftCommunity"
}

class RxAlamofireSpec: XCTestCase {
	
	var manager: Session!
	
	let testError = NSError(domain: "RxAlamofire Test Error", code: -1, userInfo: nil)
	let disposeBag = DisposeBag()
	
	//MARK: Configuration
	override func setUp() {
		super.setUp()
		manager = Session()
		
		_ = stub(condition: isHost("mywebservice.com")) { _ in
			return OHHTTPStubsResponse(data: Dummy.DataStringData, statusCode:200, headers:nil)
		}
		
		_ = stub(condition: isHost("myjsondata.com")) { _ in
			return OHHTTPStubsResponse(data: Dummy.DataJSON, statusCode:200, headers:["Content-Type":"application/json"])
		}
	}
	
	override func tearDown() {
		super.tearDown()
		OHHTTPStubs.removeAllStubs()
	}
	
	//MARK: Tests
	func testBasicRequest() {
        do {
            let (result, string) = try requestString(HTTPMethod.get, "http://mywebservice.com").toBlocking().first()!
            XCTAssertEqual(result.statusCode, 200)
            XCTAssertEqual(string, Dummy.DataStringContent)
        } catch {
            XCTFail("\(error)")
        }
	}
	
	func testJSONRequest() {
        do {
            let (result, obj) = try requestJSON(HTTPMethod.get, "http://myjsondata.com").toBlocking().first()!
            let json = obj as! [String : Any]
            XCTAssertEqual(result.statusCode, 200)
            XCTAssertEqual(json["hello"] as! String, "world")
        } catch {
            XCTFail("\(error)")
        }
	}

// TODO: In Alamofire 5 progress became immutable. Test logic should be completely changed.
//    func testProgress() {
//        do {
//            let dataRequest = try request(HTTPMethod.get, "http://myjsondata.com").toBlocking().first()!
//            let progressObservable = dataRequest.rx.progress().share(replay: 100, scope: .forever)
//            let _ = progressObservable.subscribe { }
//            let delegate = dataRequest.delegate as! DataTaskDelegate
//            let progressHandler = delegate.progressHandler!
//            [(1000, 4000), (4000, 4000)].forEach { completed, total in
//                let progress = Alamofire.Progress()
//                progress.completedUnitCount = Int64(completed)
//                progress.totalUnitCount = Int64(total)
//                progressHandler.closure(progress)
//            }
//            let actualEvents = try progressObservable.toBlocking().toArray()
//            let expectedEvents = [
//                RxProgress(bytesWritten: 0, totalBytes: 0),
//                RxProgress(bytesWritten: 1000, totalBytes: 4000),
//                RxProgress(bytesWritten: 4000, totalBytes: 4000),
//            ]
//            XCTAssertEqual(actualEvents.count, expectedEvents.count)
//            for i in 0..<actualEvents.count {
//                XCTAssertEqual(actualEvents[i], expectedEvents[i])
//            }
//        } catch {
//            XCTFail("\(error)")
//        }
//    }

    func testRxProgress() {
        let subject = RxProgress(bytesWritten: 1000, totalBytes: 4000)
        XCTAssertEqual(subject.bytesRemaining, 3000)
        XCTAssertEqual(subject.completed, 0.25, accuracy: 0.000000001)
        let similar = RxProgress(bytesWritten: 1000, totalBytes: 4000)
        XCTAssertEqual(subject, similar)
        let different = RxProgress(bytesWritten: 2000, totalBytes: 4000)
        XCTAssertNotEqual(subject, different)
    }
    
    func testDownloadResponse() {
        do {
            let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let fileURL = temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
            let myUrl = try "http://myjsondata.com".asURL()
            
            let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }
            let request = download(
                URLRequest(url: myUrl),
                to: destination
            )
            
            let testDownloadResponseExpectation = expectation(description: "testDownloadResponse expectation")
            
            _ = request
                .map {
                    $0.response { downloadResponse in
                        XCTAssertEqual(downloadResponse.response?.statusCode, 200)
                        XCTAssertNotNil(downloadResponse.fileURL)
                        testDownloadResponseExpectation.fulfill()
                    }
                }
                .subscribe {}
            
            wait(for: [testDownloadResponseExpectation], timeout: 5)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testDownloadResponseSerialized() {
        do {
            let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let fileURL = temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
            let myUrl = try "http://myjsondata.com".asURL()
            
            let destination: DownloadRequest.Destination = { _, _ in (fileURL, []) }
            let request = download(
                URLRequest(url: myUrl),
                to: destination
            )
            
            let testDownloadResponseExpectation = expectation(description: "testDownloadResponse expectation")
            
            _ = request
                .map {
                    $0.responseJSON { jsonResponse in
                        guard let json = jsonResponse.value as? [String: Any] else { XCTFail("Bad Response"); return }
                        XCTAssertEqual(json["hello"] as? String, "world")
                        testDownloadResponseExpectation.fulfill()
                    }
                }
                .subscribe {}
            
            wait(for: [testDownloadResponseExpectation], timeout: 5)
        } catch {
            XCTFail("\(error)")
        }
    }
}
