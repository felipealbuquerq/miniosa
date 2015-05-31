/*
The MIT License (MIT)

Copyright (c) 2015 Per Gantelius

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import UIKit

class ViewController: UIViewController, SimpleSineSynthDelegate{

    private var defaultFont:UIFont!
    
    private var resumeButton:UIButton!
    private var suspendButton:UIButton!
    private var startButton:UIButton!
    private var stopButton:UIButton!
    
    private var frequencyControlView:UILabel!
    
    private var inputLevelMeterLabel:UILabel!
    private var inputLevelMeterView:UIView!
    
    private var outputLevelMeterLabel:UILabel!
    private var outputLevelMeterView:UIView!
    
    private var displayLink:CADisplayLink!
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        defaultFont = UIFont(name: "HelveticaNeue-Thin", size: UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 35 : 26)
        
        SimpleSineSynth.sharedInstance().delegate = self
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func colorWithRed(red: Int, green: Int, blue: Int) -> UIColor {
        return UIColor(red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    private func createLabel(text:String, backgroundColor: UIColor) -> UILabel {
        var label = UILabel()
        label.font = defaultFont
        label.text = text
        label.backgroundColor = backgroundColor
        label.textColor = UIColor.whiteColor()
        label.textAlignment = .Center
        return label
    }
    
    private func createButton(title:String, action:String, backgroundColor: UIColor) -> UIButton {
        var button = UIButton()
        button.setTitle(title, forState: .Normal)
        button.titleLabel!.font = defaultFont
        button.addTarget(self, action: Selector(action), forControlEvents: UIControlEvents.TouchUpInside)
        button.backgroundColor = backgroundColor
        return button
    }
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor.darkGrayColor()
        
        frequencyControlView = createLabel("Tone control surface",
            backgroundColor: colorWithRed(49, green: 121, blue: 173))
        frequencyControlView.userInteractionEnabled = true
        view.addSubview(frequencyControlView)
        
        var panRecognizer = UILongPressGestureRecognizer(target: self, action: "frequencyControlPan:")
        panRecognizer.allowableMovement = CGFloat.max
        panRecognizer.minimumPressDuration = 0.0
        frequencyControlView.addGestureRecognizer(panRecognizer)
        
        resumeButton = createButton("Resume",
            action: "resumePressed:",
            backgroundColor: colorWithRed(104, green: 182, blue: 79))
        view.addSubview(resumeButton)
        
        suspendButton = createButton("Suspend",
            action: "suspendPressed:",
            backgroundColor: colorWithRed(248, green: 92 , blue: 72))
        view.addSubview(suspendButton)
        
        startButton = createButton("Start",
            action: "startPressed:",
            backgroundColor: colorWithRed(47, green: 155, blue: 72))
        view.addSubview(startButton)
        
        stopButton = createButton("Stop",
            action: "stopPressed:",
            backgroundColor: colorWithRed(190, green: 53, blue: 46))
        view.addSubview(stopButton)
        
        outputLevelMeterLabel = createLabel("Output level",
            backgroundColor: colorWithRed(57, green: 142, blue: 204))
        view.addSubview(outputLevelMeterLabel)
        
        outputLevelMeterView = UIView()
        outputLevelMeterView.backgroundColor = UIColor.whiteColor()
        outputLevelMeterView.alpha = 0.1
        view.addSubview(outputLevelMeterView);
        
        inputLevelMeterLabel = createLabel("Input level",
            backgroundColor: colorWithRed(74, green: 163, blue: 238))
        view.addSubview(inputLevelMeterLabel)
        
        inputLevelMeterView = UIView()
        inputLevelMeterView.backgroundColor = UIColor.whiteColor()
        inputLevelMeterView.alpha = 0.1
        view.addSubview(inputLevelMeterView);
    }
    
    override func viewWillAppear(animated: Bool) {
        displayLink = CADisplayLink(target: self, selector: "displayLinkCallback")
        displayLink.frameInterval = 2
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        
        let width = view.bounds.width
        let height = view.bounds.height
        let buttonHeight = view.bounds.width / (UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 8 : 4)
        let buttonWidth = view.bounds.width / 2
        
        frequencyControlView.frame = CGRect(x: 0,
            y:0,
            width: width,
            height: height - 4 * buttonHeight)
        
        inputLevelMeterLabel.frame = CGRect(x: 0,
            y:height - 4 * buttonHeight,
            width: width,
            height: buttonHeight)
        inputLevelMeterView.frame = inputLevelMeterLabel.frame
        
        outputLevelMeterLabel.frame = CGRect(x: 0,
            y:height - 3 * buttonHeight,
            width: width,
            height: buttonHeight)
        outputLevelMeterView.frame = outputLevelMeterLabel.frame
        
        startButton.frame = CGRect(x: 0,
            y: height - 2 * buttonHeight,
            width: buttonWidth,
            height: buttonHeight)
        stopButton.frame = CGRect(x: buttonWidth,
            y: height - 2 * buttonHeight,
            width: buttonWidth,
            height: buttonHeight)
        resumeButton.frame = CGRect(x: 0,
            y: height - buttonHeight,
            width: buttonWidth,
            height: buttonHeight)
        suspendButton.frame = CGRect(x: buttonWidth,
            y: height - buttonHeight,
            width: buttonWidth,
            height: buttonHeight)
    }
    
    override func viewDidDisappear(animated: Bool) {
        displayLink.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
    }

    //MARK: Display link
    func displayLinkCallback() {
        SimpleSineSynth.sharedInstance().update()
    }
    
    //MARK: UI control actions
    
    func startPressed(button:UIButton) {
        SimpleSineSynth.sharedInstance().start()
    }
    
    func stopPressed(button:UIButton) {
        SimpleSineSynth.sharedInstance().stop()
    }
    
    func suspendPressed(button:UIButton) {
        SimpleSineSynth.sharedInstance().suspend()
    }
    
    func resumePressed(button:UIButton) {
        SimpleSineSynth.sharedInstance().resume()
    }
    
    func frequencyControlPan(recognizer:UIPanGestureRecognizer) {        
        let panPos = recognizer.locationInView(frequencyControlView)
        let xRel = Float(min(1.0, max(0.0, panPos.x / frequencyControlView.bounds.width)))
        let yRel = Float(1.0 - min(1.0, max(0.0, panPos.y / frequencyControlView.bounds.height)))
        
        if recognizer.state == .Began ||
           recognizer.state == .Changed {
            SimpleSineSynth.sharedInstance().toneAmplitude = xRel
            SimpleSineSynth.sharedInstance().toneFrequency = 100.0 + 900.0 * yRel
        }
        else {
            SimpleSineSynth.sharedInstance().toneAmplitude = 0.0
            SimpleSineSynth.sharedInstance().toneFrequency = 0
        }
    }
    
    //MARK: SimpleSineSynthDelegate
    func inputLevelChanged(newLevel: Float) {
        var meterFrame = inputLevelMeterView.frame
        meterFrame.size.width = inputLevelMeterLabel.frame.width * CGFloat(newLevel)
        inputLevelMeterView.frame = meterFrame
    }
    
    func outputLevelChanged(newLevel: Float) {
        var meterFrame = outputLevelMeterView.frame
        meterFrame.size.width = outputLevelMeterLabel.frame.width * CGFloat(newLevel)
        outputLevelMeterView.frame = meterFrame
    }
}

