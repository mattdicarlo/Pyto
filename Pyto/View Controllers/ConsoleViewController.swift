//
//  ConsoleViewController.swift
//  Pyto
//
//  Created by Adrian Labbe on 9/8/18.
//  Copyright © 2018 Adrian Labbé. All rights reserved.
//

import UIKit
#if MAIN
import InputAssistant
#endif

/// A View controller containing Python script output.
class ConsoleViewController: UIViewController, UITextViewDelegate {
    
    #if MAIN
    /// The theme the user choosed.
    static var choosenTheme: Theme {
        set {
            
            let themeID: Int
            
            switch newValue {
            case is XcodeTheme:
                themeID = 0
            case is XcodeDarkTheme:
                themeID = 1
            case is BasicTheme:
                themeID = 2
            case is DuskTheme:
                themeID = 3
            case is LowKeyTheme:
                themeID = 4
            case is MidnightTheme:
                themeID = 5
            case is SunsetTheme:
                themeID = 6
            case is WWDC16Theme:
                themeID = 7
            case is CoolGlowTheme:
                themeID = 8
            case is SolarizedLightTheme:
                themeID = 9
            case is SolarizedDarkTheme:
                themeID = 10
            default:
                themeID = 0
            }
            
            UserDefaults.standard.set(themeID, forKey: "theme")
            UserDefaults.standard.synchronize()
            
            UIApplication.shared.keyWindow?.tintColor = newValue.tintColor
            
            NotificationCenter.default.post(name: ThemeDidChangedNotification, object: newValue)
        }
        
        get {
            switch UserDefaults.standard.integer(forKey: "theme") {
            case 0:
                return XcodeTheme()
            case 1:
                return XcodeDarkTheme()
            case 2:
                return BasicTheme()
            case 3:
                return DuskTheme()
            case 4:
                return LowKeyTheme()
            case 5:
                return MidnightTheme()
            case 6:
                return SunsetTheme()
            case 7:
                return WWDC16Theme()
            case 8:
                return CoolGlowTheme()
            case 9:
                return SolarizedLightTheme()
            case 10:
                return SolarizedDarkTheme()
            default:
                return XcodeTheme()
            }
        }
    }
    
    /// The Input assistant view for typing module's identifier.
    let inputAssistant = InputAssistantView()
    
    /// Code completion suggestions for the REPL.
    @objc var suggestions = [String]() {
        didSet {
            DispatchQueue.main.async {
                self.inputAssistant.reloadData()
            }
        }
    }
    
    /// Code completion suggestions values for the REPL.
    @objc var completions = [String]()
    #endif
    
    /// The current prompt.
    @objc var prompt = ""
    
    /// The content of the console.
    @objc var console = ""
    
    /// Set to `true` for asking the user for input.
    @objc var isAskingForInput = false
    
    /// The Text view containing the console.
    @objc var textView = ConsoleTextView()
    
    /// If set to `true`, the user will not be able to input.
    var ignoresInput = false
    
    /// If set to `true`, the user will not be able to input.
    static var ignoresInput = false
    
    /// Returns `true` if the UI main loop is running.
    @objc static private(set) var isMainLoopRunning = false
    
    /// Add the content of the given notification as `String` to `textView`. Called when the stderr changed or when a script printed from the Pyto module's `print` function`.
    ///
    /// - Parameters:
    ///     - notification: Its associated object should be the `String` added to `textView`.
    @objc func print_(_ notification: Notification) {
        if let output = notification.object as? String {
            DispatchQueue.main.async {
                self.console += output
                self.textView.text.append(output)
                self.textViewDidChange(self.textView)
                self.textView.scrollToBottom()
            }
        }
    }
    
    /// Requests the user for input.
    ///
    /// - Parameters:
    ///     - prompt: The prompt from the Python function
    func input(prompt: String) {
        
        guard (!ignoresInput && !ConsoleViewController.ignoresInput) || parent is REPLViewController else {
            ignoresInput = false
            ConsoleViewController.ignoresInput = false
            return
        }
        
        if !(parent is REPLViewController) {
            guard Python.shared.isScriptRunning else {
                return
            }
        }
        
        textView.text += prompt
        Python.shared.output += prompt
        textViewDidChange(textView)
        isAskingForInput = true
        textView.isEditable = true
        textView.becomeFirstResponder()
    }
    
    /// Closes the View controller and stops script.
    @objc func close() {
        
        #if MAIN
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        
        EditorViewController.visible?.stop()
        if navigationController != nil {
            dismiss(animated: true, completion: {
                if let line = EditorViewController.visible?.lineNumberError {
                    EditorViewController.visible?.lineNumberError = nil
                    EditorViewController.visible?.showErrorAtLine(line)
                }
            })
        }
        #else
        (UIApplication.shared.delegate as? AppDelegate)?.suspendApp()
        #endif
    }
    
    private static let shared = ConsoleViewController()
    
    /// The visible instance.
    @objc static var visible: ConsoleViewController {
        if Thread.current.isMainThread {
            if REPLViewController.shared?.view.window != nil {
                return REPLViewController.shared?.console ?? shared
            } else {
                return shared
            }
        } else {
            var console: ConsoleViewController?
            DispatchQueue.main.sync {
                console = ConsoleViewController.visible
            }
            return console ?? shared
        }
    }
    
    /// Closes the View controller presented from Python and stops the UI main loop.
    @objc func closePresentedViewController() {
        if presentedViewController != nil && ConsoleViewController.isMainLoopRunning {
            dismiss(animated: true) {
                ConsoleViewController.isMainLoopRunning = false
            }
        }
    }
    
    /// Shows the given View controller.
    ///
    /// - Parameters:
    ///     - viewController: The View controller to present initialized from Python.
    ///     - completion: Code to call as completion.
    @objc func showViewController(_ viewController: UIViewController, completion: (() -> Void)? = nil) {
        
        #if MAIN
        class PyNavigationController: UINavigationController {
            
            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                
                navigationBar.barStyle = ConsoleViewController.choosenTheme.barStyle
                navigationBar.barTintColor = ConsoleViewController.choosenTheme.sourceCodeTheme.backgroundColor
            }
            
            override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
                if traitCollection.horizontalSizeClass == .compact {
                    return [.portrait, .portraitUpsideDown]
                } else {
                    return super.supportedInterfaceOrientations
                }
            }
        }
        
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        vc.addChild(viewController)
        viewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 420)
        viewController.view.center = vc.view.center
        viewController.view.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        vc.view.addSubview(viewController.view)
        
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closePresentedViewController))
        
        let navVC = PyNavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .overFullScreen
        
        if navigationController != nil {
            view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
            navigationController?.view.backgroundColor = view.backgroundColor
        }
        
        present(navVC, animated: true, completion: completion)
        #else
        present(viewController, animated: true, completion: completion)
        #endif
    }
    
    // MARK: - Theme
    
    #if MAIN
    /// Setups the View controller interface for given theme.
    ///
    /// - Parameters:
    ///     - theme: The theme to apply.
    func setup(theme: Theme) {
        
        textView.inputAccessoryView = nil
        
        textView.keyboardAppearance = theme.keyboardAppearance
        textView.backgroundColor = theme.sourceCodeTheme.backgroundColor
        textView.textColor = theme.sourceCodeTheme.color(for: .plain)
        
        inputAssistant.attach(to: textView)
        inputAssistant.trailingActions = [InputAssistantAction(image: EditorSplitViewController.downArrow, target: textView, action: #selector(textView.resignFirstResponder))]
    }
    
    /// Called when the user choosed a theme.
    @objc func themeDidChanged(_ notification: Notification) {
        setup(theme: ConsoleViewController.choosenTheme)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    #endif
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if MAIN
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChanged(_:)), name: ThemeDidChangedNotification, object: nil)
        #endif
        
        edgesForExtendedLayout = []
        
        title = Localizable.console
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.isEditable = false
        view.addSubview(textView)
        
        #if MAIN
        inputAssistant.delegate = self
        inputAssistant.dataSource = self
        inputAssistant.trailingActions = [InputAssistantAction(image: EditorSplitViewController.downArrow, target: textView, action: #selector(textView.resignFirstResponder))]
        #endif
        
        NotificationCenter.default.addObserver(self, selector: #selector(print_(_:)), name: .init(rawValue: "DidReceiveOutput"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name:UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        textView.frame = view.safeAreaLayoutGuide.layoutFrame
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !(parent is REPLViewController) {
            navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(close))]
        }
        
        #if MAIN
        setup(theme: ConsoleViewController.choosenTheme)
        #endif
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
        
        view.backgroundColor = .white
        navigationController?.view.backgroundColor = .white
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard view != nil else {
            return
        }
        
        guard view.frame.height != size.height else {
            textView.frame.size.width = self.view.safeAreaLayoutGuide.layoutFrame.width
            return
        }
        
        let wasFirstResponder = textView.isFirstResponder
        textView.resignFirstResponder()
        _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { (_) in
            self.textView.frame = self.view.safeAreaLayoutGuide.layoutFrame
            if wasFirstResponder {
                self.textView.becomeFirstResponder()
            }
        }) // TODO: Anyway to to it without a timer?
    }
    
    // MARK: - Keyboard
    
    @objc func keyboardWillShow(_ notification:Notification) {
        let d = notification.userInfo!
        var r = d[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        
        r = textView.convert(r, from:nil)
        textView.contentInset.bottom = r.size.height
        textView.scrollIndicatorInsets.bottom = r.size.height
    }
    
    @objc func keyboardWillHide(_ notification:Notification) {
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
    }
    
    // MARK: - Text view delegate
    
    func textViewDidChange(_ textView: UITextView) {
        if !isAskingForInput {
            console = textView.text
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let location:Int = textView.offset(from: textView.beginningOfDocument, to: textView.endOfDocument)
        let length:Int = textView.offset(from: textView.endOfDocument, to: textView.endOfDocument)
        let end =  NSMakeRange(location, length)
        
        if end != range && !(text == "" && range.length == 1 && range.location+1 == end.location) {
            // Only allow inserting text from the end
            return false
        }
        
        if (textView.text as NSString).replacingCharacters(in: range, with: text).count >= console.count {
            
            prompt += text
            
            if text == "\n" {
                prompt = String(prompt.dropLast())
                PyInputHelper.userInput = prompt
                Python.shared.output += prompt
                prompt = ""
                isAskingForInput = false
                textView.isEditable = false
                textView.text += "\n"
                return false
            } else if text == "" && range.length == 1 {
                prompt = String(prompt.dropLast())
            }
            
            return true
        }
        
        return false
    }
}

#if MAIN
extension ConsoleViewController: InputAssistantViewDelegate, InputAssistantViewDataSource {
    
    func inputAssistantView(_ inputAssistantView: InputAssistantView, didSelectSuggestionAtIndex index: Int) {
        
        let completion = completions[index]
        prompt += completion
        textView.text += completion
        
        inputAssistantView.reloadData()
    }
    
    func textForEmptySuggestionsInInputAssistantView() -> String? {
        return nil
    }
    
    func numberOfSuggestionsInInputAssistantView() -> Int {
        return suggestions.count
    }
    
    func inputAssistantView(_ inputAssistantView: InputAssistantView, nameForSuggestionAtIndex index: Int) -> String {
        
        if suggestions[index].hasSuffix("(") {
            return suggestions[index]+")"
        }
        
        return suggestions[index]
    }
    
}
#endif
