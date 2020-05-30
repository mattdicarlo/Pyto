//
//  SceneDelagate.swift
//  Pyto
//
//  Created by Adrian Labbé on 08-06-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import SwiftUI
import SwiftUI_Views

/// The scene delegate.
@objc class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    /// A View controller to present in a new created scene.
    static var viewControllerToShow: UIViewController?
    
    /// Code called after `viewControllerToShow` is shown.
    static var viewControllerDidShow: (() -> Void)?
    
    /// RIP Memory.
    private static var windows = [UIWindow]()
    
    @available(iOS 13.0, *)
    private class ViewController: UIViewController {
        
        var justShown = true
        
        var viewControllerToPresent: UIViewController?
        
        var sceneSession: UISceneSession?
        
        var completion: (() -> Void)?
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            if justShown, let vc = viewControllerToPresent {
                vc.modalPresentationStyle = .fullScreen
                present(vc, animated: true, completion: {
                    self.completion?()
                })
            } else if let session = sceneSession {
                UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: nil)
            }
            justShown = false
        }
    }
    
    /// The document browser associated with this scene.
    var documentBrowserViewController: DocumentBrowserViewController? {
        return window?.rootViewController as? DocumentBrowserViewController
    }
    
    // MARK: - Scene delegate
    
    var window: UIWindow?
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        if let vc = SceneDelegate.viewControllerToShow {
            SceneDelegate.viewControllerToShow = nil
            
            let blankVC = ViewController()
            blankVC.sceneSession = session
            blankVC.viewControllerToPresent = vc
            blankVC.completion = SceneDelegate.viewControllerDidShow
            window?.rootViewController = blankVC
            
            return
        }
        
        window?.tintColor = ConsoleViewController.choosenTheme.tintColor
        window?.overrideUserInterfaceStyle = ConsoleViewController.choosenTheme.userInterfaceStyle
        if let window = self.window {
            SceneDelegate.windows.append(window)
        }
        
        if connectionOptions.urlContexts.count > 0 {
            self.scene(scene, openURLContexts: connectionOptions.urlContexts)
            return
        }
        
        if connectionOptions.userActivities.count > 0 {
            self.scene(scene, continue: connectionOptions.userActivities.first!)
            return
        }
        
        if let restorationActivity = session.stateRestorationActivity {
            
            if let data = restorationActivity.userInfo?["bookmarkData"] as? Data {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                    
                    (window?.rootViewController as? DocumentBrowserViewController)?.documentURL = url
                    
                    if let folder = restorationActivity.userInfo?["folderBookmarkData"] as? Data {
                        let folderURL = try URL(resolvingBookmarkData: folder, bookmarkDataIsStale: &isStale)
                        let doc = FolderDocument(fileURL: folderURL)
                        doc.open(completionHandler: nil)
                        (self.window?.rootViewController as? DocumentBrowserViewController)?.folder = doc
                    }
                } catch {
                    print(error.localizedDescription)
                }
            } else if let className = restorationActivity.userInfo?["viewControllerClass"] as? String, let ViewController = NSClassFromString(className) as? UIViewController.Type {
                
                let navClassName = restorationActivity.userInfo?["navigationControllerClass"] as? String
                var NavigationController: UINavigationController.Type?
                if let className = navClassName {
                    NavigationController = NSClassFromString(className) as? UINavigationController.Type
                }
                
                let blankVC = SceneDelegate.ViewController()
                blankVC.sceneSession = session
                if let navVC = NavigationController?.init() {
                    navVC.viewControllers = [ViewController.init()]
                    blankVC.viewControllerToPresent = navVC
                } else {
                    blankVC.viewControllerToPresent = ViewController.init()
                }
                window?.rootViewController = blankVC
                
            } else if restorationActivity.userInfo?["filePath"] != nil {
                self.scene(scene, continue: restorationActivity)
            }
        }
    }
    
    @available(iOS 13.0, *)
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        
        if shortcutItem.type == "PyPi" {
            let vc = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "pypi")
            let navVC = UINavigationController(rootViewController: vc)
            navVC.modalPresentationStyle = .formSheet
            windowScene.windows.first?.topViewController?.present(navVC, animated: true, completion: nil)
        } else if shortcutItem.type == "REPL" {
            windowScene.windows.first?.topViewController?.present(UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "repl"), animated: true, completion: nil)
        }
    }
    
    @available(iOS 13.0, *)
    func sceneWillResignActive(_ scene: UIScene) {
        #if MAIN
        (UIApplication.shared.delegate as? AppDelegate)?.copyModules()
        ((window?.rootViewController?.presentedViewController as? UINavigationController)?.viewControllers.first as? EditorSplitViewController)?.editor.save()
        #endif
    }
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        
        let root = window?.rootViewController
        
        func runScript() {
            if let path = userActivity.userInfo?["filePath"] as? String {
                
                let url = URL(fileURLWithPath: path.replacingFirstOccurrence(of: "iCloud/", with: (DocumentBrowserViewController.iCloudContainerURL?.path ?? DocumentBrowserViewController.localContainerURL.path)+"/"), relativeTo: DocumentBrowserViewController.localContainerURL)
                
                if FileManager.default.fileExists(atPath: url.path) {
                    
                    _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                        if let doc = self.documentBrowserViewController {
                            doc.revealDocument(at: url, importIfNeeded: true) { (url_, _) in
                                doc.openDocument(url_ ?? url, run: true)
                            }
                            timer.invalidate()
                        }
                    })
                } else {
                    let alert = UIAlertController(title: Localizable.Errors.errorReadingFile, message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: Localizable.ok, style: .cancel, handler: nil))
                    root?.present(alert, animated: true, completion: nil)
                }
            } else if let data = userActivity.userInfo?["filePath"] as? Data {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                    
                    if let arguments = userActivity.userInfo?["arguments"] as? [String] {
                        Python.shared.args = NSMutableArray(array: arguments)
                        UserDefaults.standard.set(arguments, forKey: "arguments\(url.path.replacingOccurrences(of: "//", with: "/"))")
                    }
                    
                    _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                        if let doc = self.documentBrowserViewController {
                            doc.revealDocument(at: url, importIfNeeded: true) { (url_, _) in
                                doc.openDocument(url_ ?? url, run: true, isShortcut: true)
                            }
                            timer.invalidate()
                        }
                    })
                } catch {
                    let alert = UIAlertController(title: Localizable.Errors.errorReadingFile, message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: Localizable.ok, style: .cancel, handler: nil))
                    root?.present(alert, animated: true, completion: nil)
                }
            } else if let code = userActivity.userInfo?["code"] as? String {
                let fileURL = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask)[0].appendingPathComponent("Shortcuts.py")
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                
                if let arguments = userActivity.userInfo?["arguments"] as? [String] {
                    Python.shared.args = NSMutableArray(array: arguments)
                    UserDefaults.standard.set(arguments, forKey: "arguments\(fileURL.path.replacingOccurrences(of: "//", with: "/"))")
                }
                
                FileManager.default.createFile(atPath: fileURL.path, contents: code.data(using: .utf8), attributes: nil)
                _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                    if let doc = self.documentBrowserViewController {
                        doc.openDocument(fileURL, run: true, isShortcut: true)
                        timer.invalidate()
                    }
                })
            } else {
                print("Invalid shortcut!")
            }
        }
        
        if root?.presentedViewController != nil {
            root?.dismiss(animated: true, completion: {
                runScript()
            })
        } else {
            runScript()
        }
    }
    
    @available(iOS 13.0, *)
    func sceneDidDisconnect(_ scene: UIScene) {
        ((window?.rootViewController?.presentedViewController as? UINavigationController)?.viewControllers.first as? EditorSplitViewController)?.editor.save()
    }
    
    @available(iOS 13.0, *)
    func sceneDidEnterBackground(_ scene: UIScene) {
        ((window?.rootViewController?.presentedViewController as? UINavigationController)?.viewControllers.first as? EditorSplitViewController)?.editor.save()
    }
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        
        guard let inputURL = URLContexts.first?.url else {
            return
        }
        
        if inputURL.scheme == "pyto" { // Select script for Today widget
            
            if inputURL.host == "inspector" {
                guard let query = inputURL.query?.removingPercentEncoding, let data = query.data(using: .utf8) else {
                    return
                }
                                
                do {
                    let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    
                    let vc = (scene as? UIWindowScene)?.windows.first?.topViewController
                    let controller = UIHostingController(rootView: JSONBrowserNavigationView(items: dict ?? [:], dismiss: {
                        vc?.dismiss(animated: true, completion: nil)
                    }))
                    vc?.present(controller, animated: true, completion: nil)
                } catch {
                    NSLog("%@", error.localizedDescription)
                }
            } else if inputURL.host == "select-script", let vc = UIStoryboard(name: "Settings", bundle: Bundle.main).instantiateInitialViewController() {
                window?.topViewController?.present(vc, animated: true, completion: {
                    let settingsVC = (vc as? UINavigationController)?.visibleViewController as? AboutTableViewController
                    
                    let indexPath = IndexPath(row: 0, section: 1)
                    settingsVC?.tableView?.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
                    _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { (_) in
                        settingsVC?.tableView(settingsVC!.tableView, didSelectRowAt: indexPath)
                    })
                })
            } else if inputURL.host == "callback" {
                PyCallbackHelper.url = inputURL.absoluteString
            } else if inputURL.host == "x-callback" {
                PyCallbackHelper.cancelURL = inputURL.queryParameters?["x-cancel"]
                PyCallbackHelper.errorURL = inputURL.queryParameters?["x-error"]
                PyCallbackHelper.successURL = inputURL.queryParameters?["x-success"]
            
                
                guard let documentBrowserViewController = documentBrowserViewController else {
                    window?.rootViewController?.dismiss(animated: true, completion: {
                        self.scene(scene, openURLContexts: URLContexts)
                    })
                    return
                }
                
                if let code = inputURL.queryParameters?["code"] {
                    PyCallbackHelper.code = code
                    documentBrowserViewController.run(code: code)
                }
            }
            
            return
        }
        
        // Open script
        
        guard let documentBrowserViewController = documentBrowserViewController else {
            window?.rootViewController?.dismiss(animated: true, completion: {
                self.scene(scene, openURLContexts: URLContexts)
            })
            return
        }
        
        // Ensure the URL is a file URL
        guard inputURL.isFileURL else {
            
            guard let query = inputURL.query?.removingPercentEncoding else {
                return
            }
            
            // Run code passed to the URL
            documentBrowserViewController.run(code: query)
            
            return
        }
        
        _ = inputURL.startAccessingSecurityScopedResource()
        
        // Reveal / import the document at the URL
        
        documentBrowserViewController.revealDocument(at: inputURL, importIfNeeded: true, completion: { (url, _) in
            
            documentBrowserViewController.openDocument(url ?? inputURL, run: false)
        })
    }
    
    // MARK: - State restoration
    
    @available(iOS 13.0, *)
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        if let presented = ((scene.delegate as? UIWindowSceneDelegate)?.window??.rootViewController?.presentedViewController as? UINavigationController)?.viewControllers.first as? EditorSplitViewController, let url = presented.editor.document?.fileURL {
            
            do {
                
                let bookmarkData = try url.bookmarkData()

                let activity = NSUserActivity(activityType: "stateRestoration")
                activity.userInfo?["bookmarkData"] = bookmarkData
                return activity
            } catch {
                return nil
            }
        } else if let splitVC = ((scene.delegate as? UIWindowSceneDelegate)?.window??.rootViewController?.presentedViewController as? EditorSplitViewController.ProjectSplitViewController), let editor = splitVC.editor, let folder = editor.folder, let url = editor.editor.document?.fileURL {
            
            do {
                
                let bookmarkData = try url.bookmarkData()
                let folderBookmarkData = try folder.fileURL.bookmarkData()
                
                let activity = NSUserActivity(activityType: "stateRestoration")
                activity.userInfo?["bookmarkData"] = bookmarkData
                activity.userInfo?["folderBookmarkData"] = folderBookmarkData
                return activity
            } catch {
                return nil
            }
        } else if let vc = ((scene.delegate as? UIWindowSceneDelegate)?.window??.rootViewController as? ViewController)?.viewControllerToPresent {
            
            let ViewController = type(of: vc) as UIViewController.Type
            
            let activity = NSUserActivity(activityType: "stateRestoration")
            if ViewController is UINavigationController.Type, let visible = (vc as? UINavigationController)?.visibleViewController {
                activity.userInfo?["navigationControllerClass"] = NSStringFromClass(ViewController)
                activity.userInfo?["viewControllerClass"] = NSStringFromClass(type(of: visible))
            } else {
                activity.userInfo?["viewControllerClass"] = NSStringFromClass(ViewController)
            }
            return activity
        }
        
        return nil
    }
}
