//
//  CalenderDayCell.swift
//  Exertia
//
//  Created by Ekansh Jindal on 02/02/26.
//

import UIKit

class CalendarDayCell: UICollectionViewCell {
    let dayLabel = UILabel()      // "SAT"
    let dateLabel = UILabel()     // "21"
    let medalImageView = UIImageView()
    private let borderView = UIView()

    // IST formatter — shared across all cells for efficiency
    private static let istTimeZone = TimeZone(identifier: "Asia/Kolkata")!
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        f.timeZone = istTimeZone
        return f
    }()
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.timeZone = istTimeZone
        return f
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        borderView.layer.cornerRadius = 12
        borderView.layer.borderWidth = 0
        borderView.layer.borderColor = UIColor.clear.cgColor
        borderView.backgroundColor = .clear
        borderView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(borderView)

        dayLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        dayLabel.textColor = .lightGray
        dayLabel.textAlignment = .center
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        dateLabel.font = .systemFont(ofSize: 13, weight: .bold)
        dateLabel.textColor = .white
        dateLabel.textAlignment = .center
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLabel)

        medalImageView.contentMode = .scaleAspectFit
        medalImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(medalImageView)

        NSLayoutConstraint.activate([
            borderView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            borderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            borderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            borderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),

            dayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            dateLabel.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 4),
            dateLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            medalImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            medalImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            medalImageView.widthAnchor.constraint(equalToConstant: 36),
            medalImageView.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    /// If target is met, the date number is replaced by a medal icon.
    /// Today gets pink-colored text. No box backgrounds on any cell.
    func configure(date: Date, isToday: Bool, targetMet: Bool, hasAbandonedSession: Bool = false) {
        dayLabel.text = Self.dayFmt.string(from: date).uppercased()
        dateLabel.text = Self.dateFmt.string(from: date)

        // Reset
        contentView.layer.borderWidth = 0
        contentView.layer.cornerRadius = 0
        contentView.backgroundColor = .clear
        borderView.layer.borderWidth = 0
        borderView.layer.borderColor = UIColor.clear.cgColor
        medalImageView.image = nil
        medalImageView.isHidden = true
        dateLabel.isHidden = false
        dayLabel.isHidden = false

        if targetMet {
            // Replace both day label and date with medal
            dateLabel.isHidden = true
            dayLabel.isHidden = true
            medalImageView.isHidden = false
            medalImageView.image = UIImage(systemName: "medal.fill")

            if isToday {
                medalImageView.tintColor = .neonPink
            } else {
                medalImageView.tintColor = .neonYellow
            }
        } else if isToday {
            dayLabel.textColor = .neonPink
            dateLabel.textColor = .neonPink
        } else {
            dayLabel.textColor = UIColor.white.withAlphaComponent(0.25)
            dateLabel.textColor = UIColor.white.withAlphaComponent(0.25)
        }

        if hasAbandonedSession && !targetMet {
            borderView.layer.borderWidth = 1
            borderView.layer.borderColor = UIColor(red: 1.0, green: 0.62, blue: 0.18, alpha: 0.8).cgColor
        }
    }
}
