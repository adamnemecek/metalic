import UIKit

class VHome:UIView
{
    weak var controller:CHome!
    private let kMenuHeight:CGFloat = 80
    
    convenience init(controller:CHome)
    {
        self.init()
        self.controller = controller
        clipsToBounds = true
        backgroundColor = UIColor.white
        translatesAutoresizingMaskIntoConstraints = false
    }
}
