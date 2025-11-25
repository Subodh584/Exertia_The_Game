
import UIKit

class StatisticsViewController: UIViewController , CustomToggleControlDelegate{

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dailyReportValueLabel: UILabel!
    @IBOutlet weak var dailyReportUnitLabel: UILabel!
    @IBOutlet weak var dailyReportTargetValueLabel: UILabel!
    @IBOutlet weak var dailyReportTargetUnitLabel: UILabel!
    @IBOutlet weak var dailyreportView: UIView!
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var lastSessionCardView: UIView!
    @IBOutlet weak var personalBestCardView: UIView!
  
    @IBOutlet weak var goalCard: WeightGoalCardView!
    
    
  
    @IBOutlet weak var dailyReportToggleControl: CustomToggleControl!
    
    @IBOutlet weak var dailyReportProgressCircleView: ProgressCircleView!
    var userProfile: UserProfile?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
          
        
        let gradientHeight: CGFloat = 200
        let gradientView = AnimatedGradientView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: gradientHeight))
        gradientView.autoresizingMask = [.flexibleWidth]
        view.insertSubview(gradientView, at: 0)
        
        nameLabel.text = "Satakshi"
        nameLabel.font = .systemFont(ofSize: 20, weight: .regular)
        nameLabel.textColor = .white
        nameLabel.alpha = 0.8
        
        headingLabel.font = .systemFont(ofSize: 20, weight: .light)
        

        dailyreportView.layer.cornerRadius = 20
        dailyreportView.clipsToBounds = true
      
        let cardCornerRadius: CGFloat = 20.0

            lastSessionCardView.layer.cornerRadius = cardCornerRadius
            lastSessionCardView.clipsToBounds = true

            personalBestCardView.layer.cornerRadius = cardCornerRadius
            personalBestCardView.clipsToBounds = true
        
        /* let widgetRadius: CGFloat = 25
            
            targetWeightWidgetView.layer.cornerRadius = widgetRadius
            targetWeightWidgetView.clipsToBounds = true
            
            todayWeightWidgetView.layer.cornerRadius = widgetRadius
            todayWeightWidgetView.clipsToBounds = true
            
            todayRuntimeWidgetView.layer.cornerRadius = widgetRadius
            todayRuntimeWidgetView.clipsToBounds = true */
        
        self.userProfile = createMockUserData()
        dailyReportToggleControl.delegate = self
        updateDailyReportCard(isCalBurnSelected: true)
        
        goalCard.setProgress(to: 0.0)
            
           
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.goalCard.setProgress(to: 0.5)
            }
    }
    func updateDailyReportCard(isCalBurnSelected: Bool) {
            guard let user = userProfile else { return }

            if isCalBurnSelected {
               
                dailyReportValueLabel.text = "\(user.dailyCaloriesBurned)"
                dailyReportUnitLabel.text = "Calories Burned"
                dailyReportTargetValueLabel.text = "\(user.dailyTargetCalories)"
                dailyReportTargetUnitLabel.text = "Target Goal"
                dailyReportValueLabel.textColor = .white
                dailyReportUnitLabel.textColor = UIColor(red: 0.8, green: 0.3, blue: 0.8, alpha: 1.0) // Magenta/Pink
                dailyReportTargetValueLabel.textColor = .white
                dailyReportTargetUnitLabel.textColor = UIColor(red: 0.8, green: 0.3, blue: 0.8, alpha: 1.0) // Magenta/Pink
                dailyReportProgressCircleView.progressRingColor = UIColor(red: 0.8, green: 0.3, blue: 0.8, alpha: 1.0) // Magenta/Pink
                            // Calculate progress: current_value / target_value
                            // Ensure no division by zero and handle cases where target might be 0
                        if user.dailyTargetCalories > 0 {
                                dailyReportProgressCircleView.progressValue = CGFloat(user.dailyCaloriesBurned) / CGFloat(user.dailyTargetCalories)
                            } else {
                                dailyReportProgressCircleView.progressValue = 0 // Or 1.0 if target is 0 but current is positive
                            }
                            dailyReportProgressCircleView.setNeedsDisplay() // Tell the view to redraw itself
        

            } else {

                dailyReportValueLabel.text = "\(user.dailyKilometers)"
                dailyReportUnitLabel.text = "Kilometers Covered"
                dailyReportTargetValueLabel.text = "\(user.dailyTargetKilometers)"
                dailyReportTargetUnitLabel.text = "Target Goal"
    

         
                dailyReportValueLabel.textColor = .white
                dailyReportUnitLabel.textColor = UIColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1.0) // Yellow
                dailyReportTargetValueLabel.textColor = .white
                dailyReportTargetUnitLabel.textColor = UIColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1.0) // Yellow
                dailyReportProgressCircleView.progressRingColor = UIColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1.0) // Yellow
                            // Calculate progress: current_value / target_value
                            if user.dailyTargetKilometers > 0 {
                                dailyReportProgressCircleView.progressValue = CGFloat(user.dailyKilometers) / CGFloat(user.dailyTargetKilometers)
                            } else {
                                dailyReportProgressCircleView.progressValue = 0 // Or 1.0 if target is 0 but current is positive
                            }
                            dailyReportProgressCircleView.setNeedsDisplay() // Tell the view to redraw itself
                        

            }
        }
    
    
    
    func toggleControl(_ control: CustomToggleControl, didSelectCalBurn isCalBurnSelected: Bool) {
            // When the toggle is tapped, this method is called.
            // We then call our update function to reflect the new state.
            updateDailyReportCard(isCalBurnSelected: isCalBurnSelected)
        }
    @IBAction func statsBackButtonTapped(_ sender: Any) {
        self.dismiss(animated: true)
    }
}

extension StatisticsViewController {
    func createMockUserData() -> UserProfile {

        
        let mockUser = UserProfile(
            

            dailyCaloriesBurned: 205,
            dailyTargetCalories: 250,
            
            dailyKilometers: 5,
            dailyTargetKilometers: 10
        )
            
        return mockUser
    }
}
