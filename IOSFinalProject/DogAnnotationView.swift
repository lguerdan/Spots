//
//  DogAnnotationView.swift
//  IOSFinalProject
//
//  Created by Grant Maloney on 12/2/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import MapKit

//class PostAnnotationView :  MKAnnotationView {
//    var dogPost : Post
//    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
//        <#code#>
//    }
//}


class DogAnnotationView: MKAnnotationView{
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if (hitView != nil)
        {
            self.superview?.bringSubview(toFront: self)
        }
        return hitView
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let rect = self.bounds;
        var isInside: Bool = rect.contains(point);
        if(!isInside)
        {
            for view in self.subviews
            {
                isInside = view.frame.contains(point);
                if isInside
                {
                    break;
                }
            }
        }
        return isInside;
    }
}
