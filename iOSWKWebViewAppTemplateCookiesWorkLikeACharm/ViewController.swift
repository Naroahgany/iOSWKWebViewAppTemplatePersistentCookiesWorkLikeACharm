//
//  ViewController.swift
//  iOSWKWebViewAppTemplateCookiesWorkLikeACharm
//
//  Kingfall 修改版：已优化状态栏颜色，修复双重网址引用问题
//

import UIKit
import WebKit

// 👇👇👇【请只修改下面这一行引号里的网址】👇👇👇
let myTargetUrl = "https://ngjgc4ugkxpsxzdxngashmha6bl54s3mrtcbg.netlify.app"
// 👆👆👆【改成你想要的网址，注意保留双引号】👆👆👆


class ViewController: UIViewController {
    
    private let webView = WKWebView(frame: .zero)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let app = UIApplication.shared
        let statusBarHeight: CGFloat = app.statusBarFrame.size.height
        let statusbarView = UIView()
        
        // 【Kingfall 优化】：原作者这里设置了粉紫色，我帮你改成了白色，更通用。
        statusbarView.backgroundColor = UIColor.white
        
        view.addSubview(statusbarView)
        
        statusbarView.translatesAutoresizingMaskIntoConstraints = false
        statusbarView.heightAnchor
            .constraint(equalToConstant: statusBarHeight).isActive = true
        statusbarView.widthAnchor
            .constraint(equalTo: view.widthAnchor, multiplier: 1.0).isActive = true
        statusbarView.topAnchor
            .constraint(equalTo: view.topAnchor).isActive = true
        statusbarView.centerXAnchor
            .constraint(equalTo: view.centerXAnchor).isActive = true
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.webView)
        NSLayoutConstraint.activate([
            self.webView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.webView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            self.webView.topAnchor.constraint(equalTo: self.view.topAnchor),
        ])
        self.view.setNeedsLayout()
        
        // 这里会自动读取我们在第一行设置的网址
        if let url = URL(string: myTargetUrl) {
            let request = URLRequest(url: url)
            webView.load(request)
            
            webView.uiDelegate = self
            webView.navigationDelegate = self
            
            // 下面这段代码是禁止用户缩放网页的（保持 App 体验），建议保留
            let source: String = "var meta = document.createElement('meta');" +
                "meta.name = 'viewport';" +
                "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" +
                "var head = document.getElementsByTagName('head')[0];" +
                "head.appendChild(meta);"
            
            let script: WKUserScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(script)
        }
        
        self.view.bringSubviewToFront(statusbarView);
    }
    
    // 【Kingfall 优化】：将状态栏文字颜色改为黑色（配合白色背景）
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
}

extension WKWebView {
    
    enum PrefKey {
        static let cookie = "cookies"
    }
    
    func writeDiskCookies(for domain: String, completion: @escaping () -> ()) {
        fetchInMemoryCookies(for: domain) { data in
            print("write data", data)
            UserDefaults.standard.setValue(data, forKey: PrefKey.cookie + domain)
            completion();
        }
    }
    
    func loadDiskCookies(for domain: String, completion: @escaping () -> ()) {
        if let diskCookie = UserDefaults.standard.dictionary(forKey: (PrefKey.cookie + domain)){
            fetchInMemoryCookies(for: domain) { freshCookie in
                
                let mergedCookie = diskCookie.merging(freshCookie) { (_, new) in new }
                
                for (_, cookieConfig) in mergedCookie {
                    let cookie = cookieConfig as! Dictionary<String, Any>
                    
                    var expire : Any? = nil
                    
                    if let expireTime = cookie["Expires"] as? Double{
                        expire = Date(timeIntervalSinceNow: expireTime)
                    }
                    
                    let newCookie = HTTPCookie(properties: [
                        .domain: cookie["Domain"] as Any,
                        .path: cookie["Path"] as Any,
                        .name: cookie["Name"] as Any,
                        .value: cookie["Value"] as Any,
                        .secure: cookie["Secure"] as Any,
                        .expires: expire as Any
                    ])
                    
                    if let validCookie = newCookie {
                        self.configuration.websiteDataStore.httpCookieStore.setCookie(validCookie)
                    }
                }
                
                completion()
            }
            
        }
        else{
            completion()
        }
    }
    
    func fetchInMemoryCookies(for domain: String, completion: @escaping ([String: Any]) -> ()) {
        var cookieDict = [String: AnyObject]()
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                if cookie.domain.contains(domain) {
                    cookieDict[cookie.name] = cookie.properties as AnyObject?
                }
            }
            completion(cookieDict)
        }
    }
}

// 这里的 URL 也是自动读取第一行的设置，不用管它
let url = URL(string: myTargetUrl)!

extension ViewController: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let host = url.host {
            webView.loadDiskCookies(for: host){
                decisionHandler(.allow)
            }
        } else {
             decisionHandler(.allow)
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let host = url.host {
            webView.writeDiskCookies(for: host){
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}
