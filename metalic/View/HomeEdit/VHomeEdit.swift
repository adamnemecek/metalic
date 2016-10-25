import UIKit

class VHomeEdit:UIView
{
    weak var controller:CHomeEdit!
    weak var menu:VHomeEditMenu!
    weak var imageView:UIImageView!
    private let kMenuHeight:CGFloat = 50
    private let kImageMargin:CGFloat = 20
    private let kStatusbarHeight:CGFloat = 20
    
    convenience init(controller:CHomeEdit)
    {
        self.init()
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black
        self.controller = controller
        
        let menu:VHomeEditMenu = VHomeEditMenu(controller:controller)
        self.menu = menu
        
        let imageView:UIImageView = UIImageView()
        imageView.isUserInteractionEnabled = false
        imageView.clipsToBounds = true
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = controller.filtered.image
        self.imageView = imageView
        
        addSubview(imageView)
        addSubview(menu)
        
        let views:[String:UIView] = [
            "menu":menu,
            "imageView":imageView]
        
        let metrics:[String:CGFloat] = [
            "menuHeight":kMenuHeight,
            "imageMargin":kImageMargin,
            "statusbarHeight":kStatusbarHeight]
        
        addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat:"H:|-0-[menu]-0-|",
            options:[],
            metrics:metrics,
            views:views))
        addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat:"H:|-(imageMargin)-[imageView]-(imageMargin)-|",
            options:[],
            metrics:metrics,
            views:views))
        addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat:"V:|-(statusbarHeight)-[menu(menuHeight)]-(imageMargin)-[imageView]-(imageMargin)-|",
            options:[],
            metrics:metrics,
            views:views))
    }
}
