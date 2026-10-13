import Foundation
import CoreGraphics
public enum AnimationTiming {
    public static func cubic(_ progress: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        let p = min(1, max(0, progress))
        func curve(_ t: Double, _ a: Double, _ b: Double) -> Double { 3*(1-t)*(1-t)*t*a + 3*(1-t)*t*t*b + t*t*t }
        var lo=0.0, hi=1.0
        for _ in 0..<18 { let m=(lo+hi)/2; if curve(m,x1,x2)<p {lo=m} else {hi=m} }
        return curve((lo+hi)/2,y1,y2)
    }
    public static func shake(_ t: Double) -> CGPoint {
        guard t>=0 && t<1 else {return .zero}
        let points=[CGPoint.zero,CGPoint(x:-3,y:2),CGPoint(x:3,y:-2),CGPoint(x:-2,y:-1),CGPoint.zero]
        let n=min(3,Int(t*4)),f=t*4-Double(n)
        return CGPoint(x:points[n].x+(points[n+1].x-points[n].x)*f,y:points[n].y+(points[n+1].y-points[n].y)*f)
    }
}
