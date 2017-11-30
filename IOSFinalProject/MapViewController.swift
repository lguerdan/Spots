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

class MapViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    
    lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.startUpdatingLocation()
        return manager
    }()
    
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
        
        let manager = self.locationManager
        self.currLocation = CLLocationCoordinate2D()
        manager.requestWhenInUseAuthorization()
        // Do any additional setup after loading the view.
        
        // test to add annotations to the mapView (STATIC THOUGH)
        let dogPost = DogPost(title: "Spot", desc: "Our mascot is out and about!", coordinate: CLLocationCoordinate2D(latitude: 38.946547, longitude: -92.328597), duration: 15)
        mapView.addAnnotation(dogPost)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
