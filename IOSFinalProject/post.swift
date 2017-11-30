//
//  post.swift
//  IOSFinalProject
//
//  Created by Luke Guerdan on 11/28/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import Foundation
import UIKit
import MapKit

struct Post {
    var name : String
    var photo: UIImageView
    var description : String
    var startTime: Date
    var duration: Int
    var latitude: Double
    var longitude: Double
    var isOwner: Bool
    var numFlags: Int
}

class DogPost: NSObject, MKAnnotation {
    let title: String?
    let desc: String
    let coordinate: CLLocationCoordinate2D
    let duration: Int
    
    init(title: String, desc: String, coordinate: CLLocationCoordinate2D, duration: Int) {
        self.title = title
        self.desc = desc
        self.coordinate = coordinate
        self.duration = duration
        
        super.init()
    }
    
    var subtitle: String? {
        return desc
    }
}
