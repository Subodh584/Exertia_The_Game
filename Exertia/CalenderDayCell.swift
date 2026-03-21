//
//  CalenderDayCell.swift
//  Exertia
//
//  Created by Ekansh Jindal on 02/02/26.
//

import UIKit

class CalendarDayCell: UICollectionViewCell {
    let bgView = UIView()
    let dayLabel = UILabel()      // "SAT"
    let dateLabel = UILabel()     // "21"
    let iconImageView = UIImageView()

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
        bgView.layer.cornerRadius = 16
        bgView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bgView)

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

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)

        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bgView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            dayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            dateLabel.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            dateLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            iconImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    /// Shows a gold medal if the daily target was met on this date (IST-aware).
    /// Today gets a purple highlight ring. All other days without a medal are plain.
    func configure(date: Date, isToday: Bool, targetMet: Bool) {
        dayLabel.text = Self.dayFmt.string(from: date).uppercased()
        dateLabel.text = Self.dateFmt.string(from: date)

        // Reset
        bgView.layer.borderWidth = 0
        bgView.backgroundColor = .clear
        iconImageView.image = nil

        if isToday {
            bgView.backgroundColor = UIColor.neonPink.withAlphaComponent(0.15)
            bgView.layer.borderWidth = 1.5
            bgView.layer.borderColor = UIColor.neonPink.cgColor
            dayLabel.textColor = .white
            dateLabel.textColor = .white
            if targetMet {
                iconImageView.image = UIImage(systemName: "medal.fill")
                iconImageView.tintColor = .neonYellow
            }
        } else if targetMet {
            bgView.backgroundColor = UIColor.neonYellow.withAlphaComponent(0.1)
            dayLabel.textColor = UIColor.white.withAlphaComponent(0.7)
            dateLabel.textColor = .white
            iconImageView.image = UIImage(systemName: "medal.fill")
            iconImageView.tintColor = .neonYellow
        } else {
            dayLabel.textColor = UIColor.white.withAlphaComponent(0.25)
            dateLabel.textColor = UIColor.white.withAlphaComponent(0.25)
        }
    }
}
