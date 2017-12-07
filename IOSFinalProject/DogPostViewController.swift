//
//  DogPostViewController.swift
//  IOSFinalProject
//
//  Created by Jeremy Gonzalez on 12/5/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import UIKit
import CoreLocation

class DogPostViewController: UIViewController {

    @IBOutlet weak var dogImage: UIImageView!
    @IBOutlet weak var dogName: UITextField!
    @IBOutlet weak var ownerName: UITextField!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var dogDesc: UITextView!
    @IBOutlet weak var bottomBar: UIToolbar!
    
    var dogPost: DogPost? = nil    
    
    let zone = Zone.defaultPublicDatabase()
    override func viewDidLoad() {
        super.viewDidLoad()
        // retrieving records
        let zone = Zone.defaultPublicDatabase()
        zone.retrieveObjects(completionHandler: { (posts: [Post]) in
            for post in posts{
                print(post.name)
            }
        })
        initDogPostUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func initDogPostUI(){
        if let dogPost = dogPost {
            dogImage.image = dogPost.photo
            dogName.text = dogPost.title
            print(dogPost.duration)
            print(dogPost.description)
            print(dogPost.startTime)
//            print(dogPost.posterName)

        }
    }

    @objc func segueToPostView() {
        performSegue(withIdentifier: "ShowCreatePost", sender: nil)
    }
    
    @objc func flagPost() {
        let alert = UIAlertController(title: "Is this post inappropriate?", message: "Would you like to flag this post?", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: {
            (alertAction) -> Void in
        }))
        alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive, handler: {
            (alertAction) -> Void in
            self.navigationController?.popViewController(animated: true)
        }))
        self.present(alert, animated: true, completion: nil)
        
        
    }
}
