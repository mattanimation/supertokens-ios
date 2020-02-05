/* Copyright (c) 2020, VRAI Labs and/or its affiliates. All rights reserved.
 *
 * This software is licensed under the Apache License, Version 2.0 (the
 * "License") as published by the Apache Software Foundation.
 *
 * You may not use this file except in compliance with the License. You may
 * obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
import Foundation
import XCTest

@testable import session

/* TODO:
 - tests APIs that don't require authentication work, before, during and after logout - using our library.***
 - test custom headers are being sent when logged in and when not.****
 - if not logged in, test that API that requires auth throws session expired.
 - if any API throws error, it gets propogated to the user properly***
 - tests other domain's (www.google.com) APIs that don't require authentication work, before, during and after logout.
 - testing doesSessionExist works fine when user is logged in****
 - Calling SuperTokens.initialise more than once works!****
 - Proper change in anti-csrf token once access token resets
 - User passed config should be sent as well****
 - Custom refresh API headers are going through*****
 - Things should work if anti-csrf is disabled.****
 */

class sessionTests: XCTestCase {
    static let testAPIBase = "http://127.0.0.1:8080/"
    let refreshTokenAPIURL = "\(testAPIBase)refresh"
    let loginAPIURL = "\(testAPIBase)login"
    let userInfoAPIURL = "\(testAPIBase)userInfo"
    let logoutAPIURL = "\(testAPIBase)logout"
    let headerAPIURL = "\(testAPIBase)header"
    let testinApiUrl = "\(testAPIBase)testing"
    let refreshCounterAPIURL = "\(testAPIBase)refreshCounter"
    let sessionExpiryCode = 440
    

    override class func tearDown() {
        let semaphore = DispatchSemaphore(value: 0)
        afterAPI(successCallback: {
            semaphore.signal()
        }, failureCallback: {
            semaphore.signal()
        })
         _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        SuperTokens.isInitCalled = false
        AntiCSRF.removeToken()
        IdRefreshToken.removeToken()
        
        let semaphore = DispatchSemaphore(value: 0)
        beforeEachAPI(successCallback: {
            semaphore.signal()
        }, failureCallback: {
            semaphore.signal()
        })
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    // TODO: redo test. tests APIs that don't require authentication work, before, during and after logout - using our library.
    func testNonAuthAPIWorksBeforeDuringAndAfterSession() {
        var failureMessage: String? = nil;
        startST(validity: 10)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
        
        var counter = getRefreshTokenCounter()  // TODO: Do not call this as the API that doesnt requie auth.. make another API like /test and call that using SuperTokensURLSession.newTask
        
        if counter != 0 {
            failureMessage = "API call before failed"
        }
        
        var url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        var requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            defer {
                requestSemaphore.signal()
            }
            
            if error != nil {
                failureMessage = "login API error"
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                }
            } else {
                failureMessage = "http response is nil";
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        counter = getRefreshTokenCounter()
        if counter != 0 {
            failureMessage = "API call during failed"
        }
        
        url = URL(string: logoutAPIURL)
        request = URLRequest(url: url!)
        request.httpMethod = "POST"
        requestSemaphore = DispatchSemaphore(value: 0)
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            if error != nil {
                failureMessage = "logout API error"
                requestSemaphore.signal()
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                } else {
                    if SuperTokens.doesSessionExist() {
                        failureMessage = "Session exists accoring to library.. but it should not!"
                    } else {
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
                        if idRefreshToken != nil || antiCSRFToken != nil {
                            failureMessage = "antiCSRF or id refresh token is not nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        counter = getRefreshTokenCounter()
        if counter != 0 {
            failureMessage = "API call after failed"
        }
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
    // tests APIs that don't require authentication work, before, during and after logout - not using our lib.
    func testNonAuthAPIWorksBeforeDuringAndAfterSessionWithURLSession() {
        var failureMessage: String? = nil;
        startST(validity: 10)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }

        var counter = getRefreshTokenCounter()
        
        if counter != 0 {
            failureMessage = "API call before failed"
        }
        
        var url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        var requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            defer {
                requestSemaphore.signal()
            }
            
            if error != nil {
                failureMessage = "login API error"
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                }
            } else {
                failureMessage = "http response is nil";
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        counter = getRefreshTokenCounter()
        if counter != 0 {
            failureMessage = "API call during failed"
        }
        
        url = URL(string: logoutAPIURL)
        request = URLRequest(url: url!)
        request.httpMethod = "POST"
        requestSemaphore = DispatchSemaphore(value: 0)
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            if error != nil {
                failureMessage = "logout API error"
                requestSemaphore.signal()
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                } else {
                    if SuperTokens.doesSessionExist() {
                        failureMessage = "Session exists accoring to library.. but it should not!"
                    } else {
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
                        if idRefreshToken != nil || antiCSRFToken != nil {
                            failureMessage = "antiCSRF or id refresh token is not nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        counter = getRefreshTokenCounter()
        if counter != 0 {
            failureMessage = "API call after failed"
        }
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
    // while logged in, test that APIs that there is proper change in id refresh stored in storage
    func testIdRefreshChange() {
        var failureMessage: String? = nil;
        startST(validity: 3)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
        
        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            if error != nil {
                failureMessage = "login API error"
                requestSemaphore.signal()
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                    requestSemaphore.signal()
                } else {
                    let idBefore = IdRefreshToken.getToken()
                    sleep(5)
                    let userInfoURL = URL(string: self.userInfoAPIURL)
                    let userInfoRequest = URLRequest(url: userInfoURL!)
                    
                    SuperTokensURLSession.newTask(request: userInfoRequest, completionHandler: {
                        userInfoData, userInfoResponse, userInfoError in
                        
                        if userInfoError != nil {
                            failureMessage = "userInfo API error"
                            requestSemaphore.signal()
                            return
                        }
                        
                        if userInfoResponse as? HTTPURLResponse != nil {
                            let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                            if userInfoHttpResponse.statusCode != 200 {
                                failureMessage = "userInfo API non 200 HTTP status code"
                            }
                            let idAfter = IdRefreshToken.getToken()
                            if idAfter == idBefore {
                                failureMessage = "id before and after are not the same!"
                            }
                            requestSemaphore.signal()
                        } else {
                            failureMessage = "userInfo API response is nil"
                            requestSemaphore.signal()
                        }
                    })
                }
            } else {
                failureMessage = "http response is nil";
                requestSemaphore.signal()
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
        
    }
    
    func testThatRequestsFailIfInitIsNotCalled() {
        var failed = true
        let semaphore = DispatchSemaphore(value: 0)
        let url = URL(string: loginAPIURL)
        let request = URLRequest(url: url!)
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            defer {
                semaphore.signal()
            }
            if error != nil {
                switch error! {
                    case SuperTokensError.illegalAccess("SuperTokens.init must be called before calling SuperTokensURLSession.newTask"):
                        failed = false
                        break
                    default:
                        break
                }
            }
        })
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        XCTAssertTrue(!failed)
    }
    
    // Calling SuperTokens.initialise more than once works
    func testMoreThanOneCallToInitWorks () {
        startST(validity: 3)
        do {
            // First call
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
            // Second Call
              try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
                XCTFail("Calling init more than once fails the test")
        }
        // Making Post Request to login and then calling init again
        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    }
                }
                requestSemaphore.signal()
        })
        do {
            // Recalling init
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        
        } catch {
            XCTFail("Calling init more than once fails the test")
        }
         _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        XCTAssertTrue(true)
    }
    
    func testIfRefreshIsCalledAfterAccessTokenExpires() {
        startST(validity: 3)
        
        var failed = false
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failed = true
        }
        
        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            if error != nil {
                failed = true
                requestSemaphore.signal()
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failed = true
                    requestSemaphore.signal()
                } else {
                    let userInfoURL = URL(string: self.userInfoAPIURL)
                    let userInfoRequest = URLRequest(url: userInfoURL!)
                    
                    sleep(5)
                    
                    SuperTokensURLSession.newTask(request: userInfoRequest, completionHandler: {
                        userInfoData, userInfoResponse, userInfoError in
                        
                        if userInfoError != nil {
                            failed = true
                            requestSemaphore.signal()
                            return
                        }
                        
                        if userInfoResponse as? HTTPURLResponse != nil {
                            let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                            if userInfoHttpResponse.statusCode != 200 {
                                failed = true
                            }
                            requestSemaphore.signal()
                        } else {
                            failed = true
                            requestSemaphore.signal()
                        }
                    })
                }
            } else {
                failed = true
                requestSemaphore.signal()
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let counter = getRefreshTokenCounter()
        if (counter != 1) {
            failed = true;
        }
        
        XCTAssertTrue(!failed)
    }
    
    // 300 requests should yield just 1 refresh call
    func testThatRefreshIsCalledOnlyOnceForMultipleThreads() {
        var failed = true
        startST(validity: 10)
        
        let runnableCount = 300

        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        let countSemaphore = DispatchSemaphore(value: 0)
        var results: [Bool] = []

        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
            SuperTokensURLSession.newTask(request: request, completionHandler: {
                data, response, error in

                if error != nil {
                    requestSemaphore.signal()
                    return
                }

                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                    } else {
                        let userInfoURL = URL(string: self.userInfoAPIURL)
                        let userInfoRequest = URLRequest(url: userInfoURL!)
                        var runnables: [() -> ()] = []
                        let resultsLock = NSObject()

                        for i in 1...runnableCount {
                            runnables.append {
                                SuperTokensURLSession.newTask(request: userInfoRequest, completionHandler: {
                                    userInfoData, userInfoResponse, userInfoError in

                                    defer {
                                        if results.count == runnableCount {
                                            requestSemaphore.signal()
                                        }
                                    }

                                    if userInfoResponse as? HTTPURLResponse != nil {
                                        let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                                        var success = false
                                        if userInfoHttpResponse.statusCode == 200 {
                                            success = true
                                        }
                                        objc_sync_enter(resultsLock)
                                        results.append(success)
                                        objc_sync_exit(resultsLock)
                                    } else {
                                        objc_sync_enter(resultsLock)
                                        results.append(false)
                                        objc_sync_exit(resultsLock)
                                    }
                                })
                            }
                        }

                        sleep(10)   // TODO: make this slightly larger ~ 12

                        runnables.forEach({
                            runnable in
                            runnable()
                        })
                    }
                } else {
                    requestSemaphore.signal()
                }
            })
        } catch {

        }

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)

        let counter = getRefreshTokenCounter()
        if (counter == 1 && !results.contains(false) && results.count == runnableCount) {
            failed = false;
        }

        XCTAssertTrue(!failed)
    }
    
    // session should not exist on frontend once logout is called
    func testThatSessionDoesNotExistAfterCallingLogout() {
        var failureMessage: String? = nil;
        startST(validity: 10)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
        
        var url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        var requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            if error != nil {
                failureMessage = "login API error"
                requestSemaphore.signal()
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                } else {
                    if !SuperTokens.doesSessionExist() {
                        failureMessage = "Session may not exist accoring to library.. but it does!"
                    } else {
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRF = AntiCSRF.getToken(associatedIdRefreshToken: idRefreshToken);
                        if idRefreshToken == nil || antiCSRF == nil {
                            failureMessage = "antiCSRF or id refresh token is nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        url = URL(string: logoutAPIURL)
        request = URLRequest(url: url!)
        request.httpMethod = "POST"
        requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            if error != nil {
                failureMessage = "logout API error"
                requestSemaphore.signal()
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                } else {
                    if SuperTokens.doesSessionExist() {
                        failureMessage = "Session exists accoring to library.. but it should not!"
                    } else {
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
                        if idRefreshToken != nil || antiCSRFToken != nil {
                            failureMessage = "antiCSRF or id refresh token is not nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
    // test custom headers are being sent when logged in and when not
   func testCheckCustomHeadersForUsers () {
        startST(validity: 10)
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
                XCTFail("Calling init more than once fails the test")
        }
        let requestSemaphore = DispatchSemaphore(value: 0)
        // Case1: When user is not logged in
       var url = URL(string: testinApiUrl)!
       var request = URLRequest(url: url)
       request.httpMethod = "POST"
        // Setting custom Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("st-custom-header", forHTTPHeaderField: "testing")
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    } else {
                        print(httpResponse)
                        if let customHeaders = httpResponse.allHeaderFields["testing"] as? String  {
                            if (customHeaders != "st-custom-header" ) {
                                requestSemaphore.signal()
                                XCTFail("Custom Header for Logged in user not equal")
                                return
                            }
                        } else {
                            requestSemaphore.signal()
                            XCTFail("Custom Header for Logged in user not equal")
                        }
                    }
                }
                requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    
       //Case2: When user is logged in
    
       //Logging in user
        url = URL(string: loginAPIURL)!
        request = URLRequest(url: url)
        request.httpMethod = "POST"
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    }
                }
                requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    
        //Making Request
        url = URL(string: testinApiUrl)!
        request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Setting custom Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("st-custom-header", forHTTPHeaderField: "testing")
    
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    } else {
                        if let customHeaders = httpResponse.allHeaderFields["testing"] as? String  {
                            if (customHeaders != "st-custom-header" ) {
                                requestSemaphore.signal()
                                XCTFail("Custom Header for Logged in user not equal")
                                return
                            }
                        } else {
                            requestSemaphore.signal()
                            XCTFail("Custom Header for Logged in user not equal")
                        }
                    }
                }
                requestSemaphore.signal()
        })
      
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        XCTAssertTrue(true)
    }
    
    // session should not exist on frontend once session has actually expired completely
    func testThatSessionDoesNotExistAfterExpiry() {
        var failureMessage: String? = nil;
        startST(validity: 3, refreshValidity: 4/60)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
         
        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
            
            if error != nil {
                failureMessage = "login API error"
                requestSemaphore.signal()
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                } else {
                    if !SuperTokens.doesSessionExist() {
                        failureMessage = "Session may not exist accoring to library.. but it does!"
                    } else {
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRF = AntiCSRF.getToken(associatedIdRefreshToken: idRefreshToken);
                        if idRefreshToken == nil || antiCSRF == nil {
                            failureMessage = "antiCSRF or id refresh token is nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            sleep(6)
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if SuperTokens.doesSessionExist() {
            failureMessage = "session exists, but it should not"
        } else {
            let idRefreshToken = IdRefreshToken.getToken()
            let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
            if idRefreshToken != nil || antiCSRFToken == nil {
                failureMessage = "antiCSRF is null or id refresh token is nil"
            }
        }
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
//    func testIfRefreshIsCalledIfAntiCSRFIsCleared() {
//        var failed = false
//        let resetSemaphore = DispatchSemaphore(value: 0)
//
////        resetAccessTokenValidity(validity: 10, failureCallback: {
////            failed = true
////            resetSemaphore.signal()
////        }, successCallback: {
////            resetSemaphore.signal()
////        })
//
//        _ = resetSemaphore.wait(timeout: DispatchTime.distantFuture)
//        let url = URL(string: loginAPIURL)
//        var request = URLRequest(url: url!)
//        request.httpMethod = "POST"
//        let requestSemaphore = DispatchSemaphore(value: 0)
//        do {
//            try SuperTokens.`init`(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
//            SuperTokensURLSession.newTask(request: request, completionHandler: {
//                data, response, error in
//
//                if error != nil {
//                    failed = true
//                    requestSemaphore.signal()
//                    return
//                }
//
//                if response as? HTTPURLResponse != nil {
//                    let httpResponse = response as! HTTPURLResponse
//                    if httpResponse.statusCode != 200 {
//                        failed = true
//                        requestSemaphore.signal()
//                    } else {
//                        let userInfoURL = URL(string: self.userInfoAPIURL)
//                        let userInfoRequest = URLRequest(url: userInfoURL!)
//
//                        AntiCSRF.removeToken()
//
//                        SuperTokensURLSession.newTask(request: userInfoRequest, completionHandler: {
//                            userInfoData, userInfoResponse, userInfoError in
//
//                            if userInfoError != nil {
//                                failed = true
//                                requestSemaphore.signal()
//                                return
//                            }
//
//                            if userInfoResponse as? HTTPURLResponse != nil {
//                                let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
//                                if userInfoHttpResponse.statusCode != 200 {
//                                    failed = true
//                                }
//                                requestSemaphore.signal()
//                            } else {
//                                failed = true
//                                requestSemaphore.signal()
//                            }
//                        })
//                    }
//                } else {
//                    failed = true
//                    requestSemaphore.signal()
//                }
//            })
//        } catch {
//            failed = true
//        }
//
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//
//        let refreshCounterSemaphore = DispatchSemaphore(value: 0)
//        getRefreshTokenCounter(successCallback: {
//            counter in
//
//            if counter != 1 {
//                failed = true
//            }
//
//            refreshCounterSemaphore.signal()
//        }, failureCallback: {
//            failed = true
//            refreshCounterSemaphore.signal()
//        })
//        _ = refreshCounterSemaphore.wait(timeout: DispatchTime.distantFuture)
//
//        XCTAssertTrue(!failed)
//    }
//
//
//    func testThatSessionPossibleExistsIsFalseAfterLogout() {
//        var failed = false
//
//        let resetSemaphore = DispatchSemaphore(value: 0)
//
////        resetAccessTokenValidity(validity: 10, failureCallback: {
////            failed = true
////            resetSemaphore.signal()
////        }, successCallback: {
////            resetSemaphore.signal()
////        })
//
//        _ = resetSemaphore.wait(timeout: DispatchTime.distantFuture)
//
//        let url = URL(string: loginAPIURL)
//        var request = URLRequest(url: url!)
//        request.httpMethod = "POST"
//        let requestSemaphore = DispatchSemaphore(value: 0)
//
//        do {
//            try SuperTokens.`init`(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
//            SuperTokensURLSession.newTask(request: request, completionHandler: {
//                data, response, error in
//
//                if error != nil {
//                    failed = true
//                    requestSemaphore.signal()
//                    return
//                }
//
//                if response as? HTTPURLResponse != nil {
//                    let httpResponse = response as! HTTPURLResponse
//                    if httpResponse.statusCode != 200 {
//                        failed = true
//                        requestSemaphore.signal()
//                    } else {
//                        let logoutURL = URL(string: self.logoutAPIURL)!
//                        var logoutRequest = URLRequest(url: logoutURL)
//                        logoutRequest.httpMethod = "POST"
//                        SuperTokensURLSession.newTask(request: logoutRequest, completionHandler: {
//                            logoutData, logoutResponse, logoutError in
//
//                            if logoutError != nil {
//                                failed = true
//                                requestSemaphore.signal()
//                                return
//                            }
//
//                            if logoutResponse as? HTTPURLResponse != nil {
//                                let httpLogoutResponse = logoutResponse as! HTTPURLResponse
//                                if httpLogoutResponse.statusCode != 200 {
//                                    failed = true
//                                    requestSemaphore.signal()
//                                    return
//                                }
//
//                                let isSessionActive = SuperTokens.sessionPossiblyExists()
//                                if isSessionActive {
//                                    failed = true
//                                }
//                                requestSemaphore.signal()
//                            } else {
//                                failed = true
//                                requestSemaphore.signal()
//                            }
//                        })
//                    }
//                } else {
//                    failed = true
//                    requestSemaphore.signal()
//                }
//            })
//        } catch {
//            failed = true
//        }
//
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//        XCTAssertTrue(!failed)
//    }
//
//    func testThatAPIWithoutAuthSucceedAfterLogout() {
//        var failed = false
//
//        let resetSemaphore = DispatchSemaphore(value: 0)
//
////        resetAccessTokenValidity(validity: 10, failureCallback: {
////            failed = true
////            resetSemaphore.signal()
////        }, successCallback: {
////            resetSemaphore.signal()
////        })
//
//        _ = resetSemaphore.wait(timeout: DispatchTime.distantFuture)
//
//        let url = URL(string: loginAPIURL)
//        var request = URLRequest(url: url!)
//        request.httpMethod = "POST"
//        let requestSemaphore = DispatchSemaphore(value: 0)
//
//        do {
//            try SuperTokens.`init`(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
//
//            SuperTokensURLSession.newTask(request: request, completionHandler: {
//                data, response, error in
//
//                if error != nil {
//                    failed = true
//                    requestSemaphore.signal()
//                    return
//                }
//
//                if response as? HTTPURLResponse != nil {
//                    let httpResponse = response as! HTTPURLResponse
//                    if httpResponse.statusCode != 200 {
//                        failed = true
//                        requestSemaphore.signal()
//                    } else {
//                        let logoutURL = URL(string: self.logoutAPIURL)!
//                        var logoutRequest = URLRequest(url: logoutURL)
//                        logoutRequest.httpMethod = "POST"
//                        SuperTokensURLSession.newTask(request: logoutRequest, completionHandler: {
//                            logoutData, logoutResponse, logoutError in
//
//                            if logoutError != nil {
//                                failed = true
//                                requestSemaphore.signal()
//                                return
//                            }
//
//                            if logoutResponse as? HTTPURLResponse != nil {
//                                let httpLogoutResponse = logoutResponse as! HTTPURLResponse
//                                if httpLogoutResponse.statusCode != 200 {
//                                    failed = true
//                                    requestSemaphore.signal()
//                                    return
//                                }
//
//                                let refreshCounterURL = URL(string: self.refreshCounterAPIURL)
//                                let refreshCounterRequest = URLRequest(url: refreshCounterURL!)
//
//                                SuperTokensURLSession.newTask(request: refreshCounterRequest, completionHandler: {
//                                    refreshCounterData, refreshCounterResponse, refreshCounterError in
//
//                                    if refreshCounterError != nil {
//                                        failed = true
//                                        requestSemaphore.signal()
//                                        return
//                                    }
//
//                                    if refreshCounterResponse as? HTTPURLResponse != nil {
//                                        let refereshCounterHttpResponse = refreshCounterResponse as! HTTPURLResponse
//                                        if refereshCounterHttpResponse.statusCode != 200 {
//                                            failed = true
//                                        }
//                                        requestSemaphore.signal()
//                                    } else {
//                                        failed = true
//                                        requestSemaphore.signal()
//                                    }
//                                })
//
//                                requestSemaphore.signal()
//                            } else {
//                                failed = true
//                                requestSemaphore.signal()
//                            }
//                        })
//                    }
//                } else {
//                    failed = true
//                    requestSemaphore.signal()
//                }
//            })
//        } catch {
//            failed = true
//        }
//
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//        XCTAssertTrue(!failed)
//    }
//
//    func testThatUserInfoAfterLogoutReturnsSessionExpiry() {
//        var failed = false
//
//        let resetSemaphore = DispatchSemaphore(value: 0)
//
////        resetAccessTokenValidity(validity: 10, failureCallback: {
////            failed = true
////            resetSemaphore.signal()
////        }, successCallback: {
////            resetSemaphore.signal()
////        })
//
//        _ = resetSemaphore.wait(timeout: DispatchTime.distantFuture)
//
//        let url = URL(string: loginAPIURL)
//        var request = URLRequest(url: url!)
//        request.httpMethod = "POST"
//        let requestSemaphore = DispatchSemaphore(value: 0)
//
//        do {
//            try SuperTokens.`init`(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
//            SuperTokensURLSession.newTask(request: request, completionHandler: {
//                data, response, error in
//
//                if error != nil {
//                    failed = true
//                    requestSemaphore.signal()
//                    return
//                }
//
//                if response as? HTTPURLResponse != nil {
//                    let httpResponse = response as! HTTPURLResponse
//                    if httpResponse.statusCode != 200 {
//                        failed = true
//                        requestSemaphore.signal()
//                    } else {
//                        let logoutURL = URL(string: self.logoutAPIURL)!
//                        var logoutRequest = URLRequest(url: logoutURL)
//                        logoutRequest.httpMethod = "POST"
//                        SuperTokensURLSession.newTask(request: logoutRequest, completionHandler: {
//                            logoutData, logoutResponse, logoutError in
//
//                            if logoutError != nil {
//                                failed = true
//                                requestSemaphore.signal()
//                                return
//                            }
//
//                            if logoutResponse as? HTTPURLResponse != nil {
//                                let httpLogoutResponse = logoutResponse as! HTTPURLResponse
//                                if httpLogoutResponse.statusCode != 200 {
//                                    failed = true
//                                    requestSemaphore.signal()
//                                    return
//                                }
//
//                                let userInfoURL = URL(string: self.userInfoAPIURL)
//                                let userInfoRequest = URLRequest(url: userInfoURL!)
//
//                                SuperTokensURLSession.newTask(request: userInfoRequest, completionHandler: {
//                                    userInfoData, userInfoResponse, userInfoError in
//
//                                    if userInfoError != nil {
//                                        failed = true
//                                        requestSemaphore.signal()
//                                        return
//                                    }
//
//                                    if userInfoResponse as? HTTPURLResponse != nil {
//                                        let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
//                                        if userInfoHttpResponse.statusCode != self.sessionExpiryCode {
//                                            failed = true
//                                        }
//                                        requestSemaphore.signal()
//                                    } else {
//                                        failed = true
//                                        requestSemaphore.signal()
//                                    }
//                                })
//
//
//                            } else {
//                                failed = true
//                                requestSemaphore.signal()
//                            }
//                        })
//                    }
//                } else {
//                    failed = true
//                    requestSemaphore.signal()
//                }
//            })
//        } catch {
//            failed = true
//        }
//
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//        XCTAssertTrue(!failed)
//    }
//
//    func testThatCustomHeadersAreSent() {
//        var failed = false
//
//        let resetSemaphore = DispatchSemaphore(value: 0)
//
////        resetAccessTokenValidity(validity: 10, failureCallback: {
////            failed = true
////            resetSemaphore.signal()
////        }, successCallback: {
////            resetSemaphore.signal()
////        })
//
//        _ = resetSemaphore.wait(timeout: DispatchTime.distantFuture)
//
//        let url = URL(string: headerAPIURL)
//        var request = URLRequest(url: url!)
//        request.addValue("st", forHTTPHeaderField: "st-custom-header")
//        let requestSemaphore = DispatchSemaphore(value: 0)
//
//        do {
//            try SuperTokens.`init`(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
//            SuperTokensURLSession.newTask(request: request, completionHandler: {
//                data, response, error in
//
//                if error != nil {
//                    failed = true
//                    requestSemaphore.signal()
//                    return;
//                }
//
//                if response as? HTTPURLResponse != nil {
//                    let httpResponse = response as! HTTPURLResponse
//
//                    if httpResponse.statusCode != 200 {
//                        failed = true;
//                        requestSemaphore.signal();
//                        return;
//                    }
//
//                    if data == nil {
//                        failed = true;
//                        requestSemaphore.signal();
//                        return;
//                    }
//
//                    do {
//                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary
//                        let success = jsonResponse.value(forKey: "success") as? Bool
//                        if success == nil {
//                            failed = true
//                            requestSemaphore.signal()
//                            return
//                        }
//
//                        if !success! {
//                            failed = true
//                        }
//
//                        requestSemaphore.signal()
//                    } catch {
//                        failed = true;
//                        requestSemaphore.signal()
//                    }
//                } else {
//                    failed = true
//                    requestSemaphore.signal()
//                }
//            })
//        } catch {
//            failed = true;
//        }
//
//        _ = requestSemaphore.wait(timeout: .distantFuture)
//        XCTAssertTrue(!failed)
//    }

}
