//
//  Created by ktiays on 2025/2/28.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import GlyphixTextFx
import UIKit

final class ToolHintView: MessageListRowView {
    enum State {
        case running
        case suceeded
        case failed
    }

    var text: String? {
        didSet { updateContentText() }
    }

    var toolName: String = .init() {
        didSet { updateContentText() }
    }

    var state: State = .running {
        didSet { updateStateImage() }
    }

    var clickHandler: (() -> Void)?

    private let backgroundGradientLayer = CAGradientLayer()
    private let label: UILabel = .init().with {
        $0.font = UIFont.preferredFont(forTextStyle: .body)
        $0.textColor = .label
        $0.minimumScaleFactor = 0.5
        $0.adjustsFontForContentSizeCategory = true
        $0.lineBreakMode = .byTruncatingTail
        $0.numberOfLines = 1
        $0.adjustsFontSizeToFitWidth = true
        $0.textAlignment = .left
    }

    private let symbolView: UIImageView = .init().with {
        $0.contentMode = .scaleAspectFit
    }

    private let decoratedView: UIImageView = .init(image: .init(named: "tools"))
    private let loadingSymbol: LoadingSymbol = .init().with {
        $0.dotRadius = 2.5
        $0.spacing = 4
        $0.animationDuration = 0.4
        $0.animationInterval = 0.12
        $0.delay = 0.1
    }

    private var isClickable: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        decoratedView.contentMode = .scaleAspectFit
        decoratedView.tintColor = .label

        backgroundGradientLayer.startPoint = .init(x: 0.6, y: 0)
        backgroundGradientLayer.endPoint = .init(x: 0.4, y: 1)

        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous
        contentView.layer.insertSublayer(backgroundGradientLayer, at: 0)
        contentView.addSubview(decoratedView)
        contentView.addSubview(symbolView)
        contentView.addSubview(label)
        contentView.addSubview(loadingSymbol)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        contentView.addGestureRecognizer(tapGesture)

        updateStateImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labelSize = label.intrinsicContentSize

        symbolView.frame = .init(
            x: 12,
            y: (contentView.bounds.height - labelSize.height) / 2,
            width: labelSize.height, // 1:1
            height: labelSize.height
        )

        label.frame = .init(
            x: symbolView.frame.maxX + 8,
            y: (contentView.bounds.height - labelSize.height) / 2,
            width: labelSize.width,
            height: labelSize.height
        )

        // 只在运行状态显示 loading symbol
        let loadingSize: CGSize = state == .running ? .init(width: 26, height: 12) : .zero
        loadingSymbol.frame = .init(
            x: label.frame.maxX + 2,
            y: (contentView.bounds.height - loadingSize.height) / 2,
            width: loadingSize.width,
            height: loadingSize.height
        )

        contentView.frame.size.width = label.frame.maxX + (state == .running ? loadingSize.width + 2 : 0) + 18
        decoratedView.frame = .init(x: contentView.bounds.width - 12, y: -4, width: 16, height: 16)
        backgroundGradientLayer.frame = contentView.bounds
        backgroundGradientLayer.cornerRadius = contentView.layer.cornerRadius
    }

    override func themeDidUpdate() {
        super.themeDidUpdate()
        label.font = theme.fonts.body
    }

    private func updateStateImage() {
        let configuration = UIImage.SymbolConfiguration(scale: .small)
        switch state {
        case .suceeded:
            backgroundGradientLayer.colors = [
                UIColor.systemGreen.withAlphaComponent(0.08).cgColor,
                UIColor.systemGreen.withAlphaComponent(0.12).cgColor,
            ]
            let image = UIImage(systemName: "checkmark.seal", withConfiguration: configuration)
            symbolView.image = image
            symbolView.tintColor = .systemGreen
            loadingSymbol.isHidden = true
        case .running:
            backgroundGradientLayer.colors = [
                UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.12).cgColor,
            ]
            let image = UIImage(systemName: "hourglass", withConfiguration: configuration)
            symbolView.image = image
            symbolView.tintColor = .systemBlue
            loadingSymbol.isHidden = false
        default:
            backgroundGradientLayer.colors = [
                UIColor.systemRed.withAlphaComponent(0.08).cgColor,
                UIColor.systemRed.withAlphaComponent(0.12).cgColor,
            ]
            let image = UIImage(systemName: "xmark.seal", withConfiguration: configuration)
            symbolView.image = image
            symbolView.tintColor = .systemRed
            loadingSymbol.isHidden = true
        }
        postUpdate()
    }

    private func updateContentText() {
        switch state {
        case .running:
            isClickable = false
            label.text = .init(localized: "Tool call for \(toolName) running")
        case .suceeded:
            isClickable = true
            label.text = .init(localized: "Tool call for \(toolName) completed.")
        case .failed:
            isClickable = true
            label.text = .init(localized: "Tool call for \(toolName) failed.")
        }
        postUpdate()
    }

    func postUpdate() {
        label.invalidateIntrinsicContentSize()
        label.sizeToFit()
        setNeedsLayout()

        doWithAnimation {
            self.layoutIfNeeded()
        }
    }

    @objc
    private func handleTap(_ sender: UITapGestureRecognizer) {
        if isClickable, sender.state == .ended {
            clickHandler?()
        }
    }
}
