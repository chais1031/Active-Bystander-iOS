import UIKit
import CoreLocation

class ProfileScreenController: UIViewController {
    var helpAreas = [MHelpArea]()

    private weak var locationTrackingCell: SettingsSwitchCell?
    private weak var locationManager: CLLocationManager?

    @IBOutlet weak var helpAreaTable: UITableView!

    @IBAction func logOutButtonPress(_ sender: UIButton) {
        Environment.userAuth.logOut()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        helpAreaTable.reloadData()
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            locationManager = appDelegate.locationManager
            let selector = #selector(locationManagerChangedAuthorization(notification:))
            appDelegate.notificationCenter.addObserver(self, selector: selector,
                                                       name: .AVLocationAuthorizationNotification, object: nil)
        }

        refreshProfile()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editingSegue" {
            guard let destination = segue.destination as? UINavigationController,
                let editController = destination.topViewController as? ProfileEditScreenController else {
                    return
            }

            editController.delegate = self
            editController.selectedHelpAreas = self.helpAreas
        }
    }

    func refreshProfile() {
        // swiftlint:disable unused_closure_parameter
        Environment.backend.read(MProfileRequest()) { (success, profile: MProfile?) in
        }
        // swiftlint:enable unused_closure_parameter
    }
}

extension ProfileScreenController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ProfileScreenController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // if the section is not 0, then it is General which only has one row
        return section == 0 ? helpAreas.count : 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "helpAreaCell", for: indexPath)
            cell.textLabel?.text = helpAreas[indexPath.row].situation
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "switch", for: indexPath)
        guard let switchCell = cell as? SettingsSwitchCell else {
            return cell
        }

        locationTrackingCell = switchCell
        switchCell.kind = .locationTracking
        switchCell.titleLabel.text = switchCell.kind?.label
        switchCell.action = { [weak locationManager] (isOn: Bool) -> Void in
            if isOn {
                locationManager?.requestAlwaysAuthorization()
            }
            UserDefaults.this.isLocationEnabled = isOn
        }
        switchCell.toggleSwitch.isOn = UserDefaults.this.isLocationEnabled
        return switchCell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Help Area"
        default:
            return "General"
        }
    }

}

extension ProfileScreenController {
    @objc func locationManagerChangedAuthorization(notification: Notification) {
        guard let status = notification.userInfo?[0] as? CLAuthorizationStatus else {
            return
        }

        if !CLLocationManager.locationServicesEnabled() || status != .authorizedAlways {
            UserDefaults.this.isLocationEnabled = false
            if locationTrackingCell?.kind == .locationTracking {
                locationTrackingCell?.toggleSwitch.isOn = false
            }
        }
    }
}

extension ProfileScreenController: ProfileEditScreenControllerDelegate {
    func profileEditScreenController(_ editScreen: ProfileEditScreenController,
                                     updateHelpAreas helpAreas: [MHelpArea]) {
        self.helpAreas = helpAreas
        helpAreaTable.reloadData()
    }
}
