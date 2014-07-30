//
//  ViewController.swift
//  SwiftMail
//
//  Created by Ben Gotow on 7/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

import UIKit
import Inbox

class ThreadViewController: UIViewController, INModelProviderDelegate {

    var threadProvider: INThreadProvider?

    @IBOutlet var subjectLabel: UILabel!
    @IBOutlet var participantsLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var snippetLabel: UILabel!

    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        INAPIManager.shared().authenticateWithAuthToken("not-required", {(success:Bool, error: NSError?) -> Void in
            // Since we're connecting to the open source Inbox sync engine,
            // we don't need an API token.
            var namespaces = INAPIManager.shared().namespaces()
            var namespace = namespaces[0] as? INNamespace
            
            var provider:INThreadProvider! = namespace?.newThreadProvider();
            provider.itemFilterPredicate = NSComparisonPredicate(format: "ANY tagIDs = \"unread\"")
            provider.itemSortDescriptors = [NSSortDescriptor(key: "lastMessageDate", ascending: false)]
            provider.itemRange = NSRange(location: 0, length: 100)
            provider.delegate = self;
            self.threadProvider = provider;
        });
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // we must be the first responder to hear about shake events
        self.becomeFirstResponder()
    }
    
    
    @IBAction
    func refreshInterface() {
        var items = self.threadProvider!.items
        
        // if we don't have any unread items, clear everything and return
        if items.count == 0 {
            self.subjectLabel.text = "No unread threads!"
            self.snippetLabel.text = ""
            self.participantsLabel.text = ""
            self.dateLabel.text = ""
            return
        }

        // if we have a thread, show it!
        if let thread = items[0] as? INThread {
            self.subjectLabel.text = thread.subject
            self.snippetLabel.text = thread.snippet
            
            var formatter = NSDateFormatter()
            formatter.dateStyle = NSDateFormatterStyle.MediumStyle;
            formatter.timeStyle = NSDateFormatterStyle.ShortStyle;
            self.dateLabel.text = formatter.stringFromDate(thread.lastMessageDate);
            
            // collect the names of the participants, except for ourselves
            // to populate the names nicely.
            var namespaces = INAPIManager.shared().namespaces()

            if let namespace = namespaces[0] as? INNamespace {
                var myEmail = namespace.emailAddress as String
                var names:[String] = [];
                for participant in thread.participants {
                    if participant["email"] as String == myEmail {
                        names.append("Me")
                    } else if countElements(participant["name"] as String) > 0 {
                        names.append(participant["name"] as String)
                    } else {
                        names.append(participant["email"] as String)
                    }
                }
                self.participantsLabel.text = ", ".join(names[0...names.count-2]) + " and " + names[names.count-1]
            }
        }
    }
    
    @IBAction
    func markThreadAsRead() {
        var items = self.threadProvider!.items
        if let thread = items[0] as? INThread {
            thread.markAsRead()
        }
    }
    
    func displayError(error: NSError!) {
        var alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
        
    // INModelProvider Delegate
    
    func providerDataChanged(provider: INModelProvider!) {
        self.refreshInterface()
    }
    
    func provider(provider: INModelProvider!, dataFetchFailed error: NSError!)  {
        self.displayError(error);
    }
    
    // Handling Swipe Gesture
    
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent!) {
        if (motion == UIEventSubtype.MotionShake) {
            self.markThreadAsRead();
        }
    }
}

