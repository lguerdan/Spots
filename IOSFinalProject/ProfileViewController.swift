//
//  ProfileViewController.swift
//  IOSFinalProject
//
//  Created by Cameron Wandfluh on 12/7/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import UIKit

class ProfileViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var bottomToolBar: UIToolbar!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var postersName: UILabel!
    @IBOutlet weak var usersPosts: UITableView!
    var posts: [Post] = []
    
    var username: String = ""
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
        
        usersPosts.delegate = self
        usersPosts.dataSource = self
        
        self.postersName.text = self.username
        
        loadAndPopulatePostVar()
    }
    
    func loadAndPopulatePostVar() {
        // Retrieve records
        let zone = Zone.defaultPublicDatabase()
        zone.retrieveObjects(completionHandler: { (posts: [Post]) in
            self.posts = posts
            
            print(self.username)
            self.posts = self.posts.filter() { $0.posterName == self.username }
            
            
            print(self.posts.count)
            
            self.usersPosts.reloadData()
        })
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
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.posts.count == 0 {
            return 1
        }
        return self.posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if self.posts.count == 0 {
            cell.textLabel?.text = "Loading post history..."
            cell.imageView?.image = nil
            cell.detailTextLabel?.text = ""
            return cell
        }
        
        let post = posts[indexPath.row]
        
        cell.textLabel?.text = post.name
        cell.detailTextLabel?.text = "Poster: \(post.posterName)"
        cell.imageView?.image = post.photo?.image
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            
        }
    }
}
