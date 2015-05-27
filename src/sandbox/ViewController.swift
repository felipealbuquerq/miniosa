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
    private var frequencySlider:UISlider!
    
    private var displayLink:CADisplayLink!
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor.darkGrayColor()
        
        frequencySlider = UISlider()
        frequencySlider.addTarget(self, action: "frequencySliderChanged:", forControlEvents: .ValueChanged)
        view.addSubview(frequencySlider)
        
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
    
    override func viewWillAppear(animated: Bool) {
        displayLink = CADisplayLink(target: self, selector: "displayLinkCallback")
        displayLink.frameInterval = 2
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
    }
    
    override func viewDidDisappear(animated: Bool) {
        displayLink.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var views = [startButton, stopButton, suspendButton, resumeButton, frequencySlider]
        
        let buttonX:CGFloat = 20
        let buttonHeight:CGFloat = 44
        let buttonSpacing:CGFloat = 50
        let buttonWidth = view.bounds.size.width - 2 * buttonX

        for i in 0..<views.count {
            
            var button = views[i]
            button.frame = CGRectMake(buttonX, buttonX + CGFloat(i) * buttonSpacing, buttonWidth, buttonHeight)
        }
    }
    
    //MARK: Display link
    func displayLinkCallback() {
        MyAudioEngine.sharedInstance().update()
    }
    
    //MARK: UI control actions
    
    func startPressed(button:UIButton) {
        MyAudioEngine.sharedInstance().start()
    }
    
    func stopPressed(button:UIButton) {
        MyAudioEngine.sharedInstance().stop()
    }
    
    func suspendPressed(button:UIButton) {
        MyAudioEngine.sharedInstance().suspend()
    }
    
    func resumePressed(button:UIButton) {
        MyAudioEngine.sharedInstance().resume()
    }
    
    func frequencySliderChanged(slider:UISlider) {
        MyAudioEngine.sharedInstance().toneFrequency = 300 + 700 * slider.value
    }
}

