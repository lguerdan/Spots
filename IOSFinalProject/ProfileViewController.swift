//
//  ProfileViewController.swift
//  IOSFinalProject
//
//  Created by Cameron Wandfluh on 12/7/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import UIKit

class ProfileViewController: UIViewController {

    @IBOutlet weak var bottomToolBar: UIToolbar!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //circular UIimage(kind of)
        imageView.layer.cornerRadius = imageView.frame.size.width/2
        imageView.layer.cornerRadius = imageView.frame.size.height/2
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor(rgb: 0xE77C1E).cgColor
        
        // change of font and font color of navigation controller
        self.navigationController?.navigationBar.titleTextAttributes = [ NSAttributedStringKey.font: UIFont(name: "Gujarati Sangam MN", size: 20)!, NSAttributedStringKey.foregroundColor: UIColor.white]
        
        //back button color
        self.navigationController?.navigationBar.tintColor = UIColor.white
        
        // Do any additional setup after loading the view.
        setImageIcons()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setImageIcons() {
        //E77C1E
        let postButton: UIButton = UIButton(type: UIButtonType.custom)
        postButton.frame.size = CGSize(width: 30, height: 30)
        //set frame
        let postSize = postButton.frame.size
        let postImage = UIImage(named: "Plus")?.resizedImageWithinSquare(rectSize: postSize)
        postButton.setImage(postImage, for: .normal)
        let bottomBarButton = UIBarButtonItem(customView: postButton)
        //assign button to bottombar
        self.bottomToolBar.setItems([bottomBarButton], animated: false)
        //Need to add segue to the createpost
        postButton.addTarget(self, action: #selector(segueToPostView), for: .touchUpInside)
    }
    

    @objc func segueToPostView() {
        performSegue(withIdentifier: "ShowCreatePost", sender: nil)
    }
}
