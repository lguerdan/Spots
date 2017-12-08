//
//  MapViewController.swift
//  IOSFinalProject
//
//  Created by Cameron Wandfluh on 11/16/17.
//  Copyright © 2017 Team 4. All rights reserved.
//
import CoreLocation
import UIKit
import MapKit

class MapViewController: UIViewController, CLLocationManagerDelegate, CreatePostViewControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    
    @IBOutlet weak var bottomToolBar: UIToolbar!
    @IBOutlet weak var moveToCreatePost: UIBarButtonItem!
    @IBOutlet weak var moveToProfile: UIBarButtonItem!
    lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.startUpdatingLocation()
        return manager
    }()
    
    var selectedAnnotation : DogPost?
    
    var posts: [Post] = []
    
    var currLocation : CLLocationCoordinate2D = CLLocationCoordinate2D()
    var regionRadius: CLLocationDistance = 1000
    
    convenience init() {
        self.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setting the initial location to Columbia, MO for testing purposes?
        // want to eventually set the initial location to a radius around the user...
        let initialLocation = CLLocation(latitude: 38.9404, longitude: -92.3277)
        centerMapOnLocation(location: initialLocation)
        
        mapView.delegate = self
        
        // change of font and font color of navigation controller
        self.navigationController?.navigationBar.titleTextAttributes = [ NSAttributedStringKey.font: UIFont(name: "Gujarati Sangam MN", size: 20)!, NSAttributedStringKey.foregroundColor: UIColor.white]
        
        let manager = self.locationManager
        self.currLocation = CLLocationCoordinate2D()
        manager.requestWhenInUseAuthorization()
        
        // Retrieve records
        let zone = Zone.defaultPublicDatabase()
        zone.retrieveObjects(completionHandler: { (posts: [Post]) in
            self.posts = posts
            // Reload data

            //So, the lat and long is insanely small. The example below knocks off 2 of the 5 posts
            //let collectedPosts: [Post] = self.populateByRadius(0.005, self.posts)
            
            //This is an example of owner sorting
            //let collectedPosts: [Post] = self.getOwnersPosts("GrantMaloney", self.posts)
            
            //This is an example of duration sorting, will return posts = to or < duration specified
            //let collectedPosts: [Post] = self.populateByDuration(5, self.posts)
            
            for post in self.posts {
                let dogPost = DogPost(title: post.name, desc: post.description, coordinate: CLLocationCoordinate2D(latitude: post.latitude, longitude: post.longitude), duration: post.duration,photo: (post.photo?.image)!,name: post.posterName, posterName: post.posterName, startTime: post.startTime)
                
                
                self.mapView.addAnnotation(dogPost)
            }
        })
        
        setImageIcons()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func populateByRadius(_ radius: Double, _ posts: [Post]) -> [Post] {
        var populatedPosts: [Post] = []
        
        let rangeUpDownHigh = self.currLocation.latitude + radius
        let rangeLeftRightHigh = self.currLocation.longitude + radius
        
        let rangeUpDownLow = self.currLocation.latitude - radius
        let rangeLeftRightLow = self.currLocation.longitude - radius
        
        for post in posts {
            if (post.latitude >= rangeUpDownLow && post.latitude <= rangeUpDownHigh)
                && (post.longitude >= rangeLeftRightLow && post.longitude <= rangeLeftRightHigh) {
                populatedPosts.append(post)
            }
        }
        
        return populatedPosts
    }
    
    func finishPassing(post: DogPost) {
        self.mapView.addAnnotation(post)
    }
    
    func getOwnersPosts(_ name: String, _ posts: [Post]) -> [Post] {
        var populatedPosts: [Post] = []
        
        for post in posts {
            if name == post.posterName {
                populatedPosts.append(post)
            }
        }
        
        return populatedPosts
    }
    
    func populateByDuration(_ duration: Int, _ posts: [Post]) -> [Post] {
        var populatedPosts: [Post] = []
        
        for post in posts {
            if post.duration <= duration {
                populatedPosts.append(post)
            }
        }
        
        return populatedPosts
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locationManager.location != nil{
            currLocation = locationManager.location!.coordinate
            print("locations = \(currLocation.latitude) \(currLocation.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print(error)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if case .authorizedWhenInUse = status{
            manager.requestLocation()
        } else {
            print(status)
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let CreatePostViewController = segue.destination as? CreatePostViewController {
            CreatePostViewController.latitude = currLocation.latitude
            CreatePostViewController.longitude = currLocation.longitude
        }
        
        if let destination = segue.destination as? CreatePostViewController {
            destination.delegate = self
        }
        
        if segue.identifier == "ShowDogPost" {
            if let DogPostViewController = segue.destination as? DogPostViewController {
                DogPostViewController.dogPost = selectedAnnotation
            }
        }
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkLocationAuthorizationStatus()
    }
    
    let locationManager2 = CLLocationManager()
    func checkLocationAuthorizationStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            mapView.showsUserLocation = true
        } else {
            locationManager2.requestAlwaysAuthorization()
        }
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
        
        
        let profileButton: UIButton = UIButton(type: UIButtonType.custom)
        profileButton.frame.size = CGSize(width: 30, height: 30)
        //add function for button
        profileButton.addTarget(self, action: #selector(segueToProfile), for: UIControlEvents.touchUpInside)
        //set frame
        let profileSize = profileButton.frame.size
        let profileImage = UIImage(named: "Profile")?.resizedImageWithinSquare(rectSize: profileSize)
        profileButton.setImage(profileImage, for: .normal)
        
        let barButton = UIBarButtonItem(customView: profileButton)
        //assign button to navigationbar
        self.navigationItem.rightBarButtonItem = barButton
        
        performSegue(withIdentifier: "ShowDogPost", sender: nil)
        
    }
    
    @objc func segueToPostView() {
        performSegue(withIdentifier: "ShowCreatePost", sender: nil)
    }

    @objc func segueToProfile() {
        performSegue(withIdentifier: "ShowProfile", sender: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension MapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        
        guard let annotation = annotation as? DogPost else { return nil }
        
        let identifier = "marker"
        var view: MKAnnotationView
        
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
            dequeuedView.annotation = annotation
            view = dequeuedView
        } else {
            
            view = DogAnnotationView(annotation: annotation, reuseIdentifier: "Pin")
            view.canShowCallout = true
            view.calloutOffset = CGPoint(x: -5, y: 5)
            let rightButton: AnyObject! = UIButton(type: UIButtonType.detailDisclosure)
            view.rightCalloutAccessoryView = rightButton as? UIView

        }
        view.image = annotation.photo.resizedImageWithinSquare(rectSize: CGSize(width: 56, height: 56))
        let zone = Zone.defaultPublicDatabase()
        zone.userInformation(completionHandler: { (user, error) in
            DispatchQueue.main.async {
                guard error == nil else {
                    print("User error")
                    return
                }
                
                var userName : String
                userName = user?.firstName ?? ""
                userName += user?.lastName ?? ""
                
                if userName == annotation.name {
                    view.image = self.maskRoundedImage(image: view.image!, radius: 28, color: UIColor(rgb: 0x4286f4).cgColor)
                } else {
                    view.image = self.maskRoundedImage(image: view.image!, radius: 28, color: UIColor(rgb: 0xE77C1E).cgColor)
                }
            }
        })
        sleep(1)
        return view
    }
    
    func maskRoundedImage(image: UIImage, radius: CGFloat, color: CGColor) -> UIImage {
        let imageView: UIImageView = UIImageView(image: image)
        let layer = imageView.layer
        layer.masksToBounds = true
        layer.cornerRadius = radius
        layer.borderWidth = 3
        layer.borderColor = color
        UIGraphicsBeginImageContext(imageView.bounds.size)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return roundedImage!
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl){
        if control == view.rightCalloutAccessoryView {
            selectedAnnotation = view.annotation as? DogPost
            performSegue(withIdentifier: "ShowDogPost", sender: self)
        }
    }

}

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}

extension UIImage {
    /// Returns a image that fills in newSize
    func resizedImage(newSize: CGSize) -> UIImage {
        // Guard newSize is different
        guard self.size != newSize else { return self }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    
    /// Returns a resized image that fits in rectSize, keeping it's aspect ratio
    /// Note that the new image size is not rectSize, but within it.
    func resizedImageWithinRect(rectSize: CGSize) -> UIImage {
        let widthFactor = size.width / rectSize.width
        let heightFactor = size.height / rectSize.height
        
        var resizeFactor = widthFactor
        if size.height > size.width {
            resizeFactor = heightFactor
        }
        
        let newSize = CGSize(width: size.width/resizeFactor, height: size.height/resizeFactor)
        let resized = resizedImage(newSize: newSize)
        return resized
    }
    
    func resizedImageWithinSquare(rectSize: CGSize) -> UIImage {
        let minValue = min(rectSize.height, rectSize.width)
        let size = CGSize(width: minValue, height: minValue)
        
        return self.resizedImage(newSize: size)
    }
}
