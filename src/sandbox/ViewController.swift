//
//  ViewController.swift
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    private var resumeButton:UIButton!
    private var suspendButton:UIButton!
    private var startButton:UIButton!
    private var stopButton:UIButton!
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor.darkGrayColor()
        
        resumeButton = UIButton()
        resumeButton.setTitle("resume", forState: .Normal)
        resumeButton.addTarget(self, action: "resumePressed:", forControlEvents: .TouchUpInside)
        view.addSubview(resumeButton)
        
        suspendButton = UIButton()
        suspendButton.setTitle("suspend", forState: .Normal)
        suspendButton.addTarget(self, action: "suspendPressed:", forControlEvents: .TouchUpInside)
        view.addSubview(suspendButton)
        
        startButton = UIButton()
        startButton.setTitle("start", forState: .Normal)
        startButton.addTarget(self, action: "startPressed:", forControlEvents: .TouchUpInside)
        view.addSubview(startButton)
        
        stopButton = UIButton()
        stopButton.setTitle("stop", forState: .Normal)
        stopButton.addTarget(self, action: "stopPressed:", forControlEvents: .TouchUpInside)
        view.addSubview(stopButton)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var buttons = [startButton, stopButton, suspendButton, resumeButton]
        
        let buttonX:CGFloat = 20
        let buttonHeight:CGFloat = 44
        let buttonSpacing:CGFloat = 50
        let buttonWidth = view.bounds.size.width - 2 * buttonX

        for i in 0..<buttons.count {
            
            var button = buttons[i]
            button.frame = CGRectMake(buttonX, buttonX + CGFloat(i) * buttonSpacing, buttonWidth, buttonHeight)
        }
    }
    
    //MARK: Button actions
    
    func startPressed(button:UIButton) {
        AudioEngine.sharedInstance().start()
    }
    
    func stopPressed(button:UIButton) {
        AudioEngine.sharedInstance().stop()
    }
    
    func suspendPressed(button:UIButton) {
        AudioEngine.sharedInstance().suspend()
    }
    
    func resumePressed(button:UIButton) {
        AudioEngine.sharedInstance().resume()
    }
}

