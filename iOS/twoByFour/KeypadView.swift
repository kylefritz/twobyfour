import TwoByFourKit
import UIKit

/// The carpenter keypad, shown in place of the iPhone keyboard. A slim row
/// of less-used keys sits above a big grid a thumb can hit with gloves on.
///
///     (    )    =    x    ÷   abc
///     ft'  7    8    9    ⌫
///     in"  4    5    6    ×
///     /    1    2    3    −
///     ␣    .    0    ⏎    +
final class KeypadView: UIInputView {
    enum Action {
        case key(KeypadKey)
        case letters
    }

    private enum Style { case digit, unit, op, function }

    private struct Spec {
        let title: String
        let action: Action
        let style: Style
        let label: String
    }

    private let send: (Action) -> Void
    private var repeatTimer: Timer?

    init(send: @escaping (Action) -> Void) {
        self.send = send
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 262), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        build()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 262) }

    private static let slim: [Spec] = [
        Spec(title: "(", action: .key(.openParen), style: .op, label: "open parenthesis"),
        Spec(title: ")", action: .key(.closeParen), style: .op, label: "close parenthesis"),
        Spec(title: "=", action: .key(.equals), style: .op, label: "equals"),
        Spec(title: "x", action: .key(.board), style: .unit, label: "by, as in 2 by 4"),
        Spec(title: "÷", action: .key(.divide), style: .op, label: "divide"),
        Spec(title: "abc", action: .letters, style: .function, label: "letters"),
    ]

    private static func digit(_ n: Int) -> Spec {
        Spec(title: String(n), action: .key(.digit(n)), style: .digit, label: String(n))
    }

    private static let grid: [[Spec]] = [
        [Spec(title: "ft '", action: .key(.feet), style: .unit, label: "feet"),
         digit(7), digit(8), digit(9),
         Spec(title: "⌫", action: .key(.delete), style: .function, label: "delete")],
        [Spec(title: "in \"", action: .key(.inches), style: .unit, label: "inches"),
         digit(4), digit(5), digit(6),
         Spec(title: "×", action: .key(.times), style: .op, label: "times")],
        [Spec(title: "/", action: .key(.slash), style: .unit, label: "fraction slash"),
         digit(1), digit(2), digit(3),
         Spec(title: "−", action: .key(.minus), style: .op, label: "minus")],
        [Spec(title: "space", action: .key(.space), style: .function, label: "space"),
         Spec(title: ".", action: .key(.point), style: .digit, label: "point"),
         digit(0),
         Spec(title: "⏎", action: .key(.newline), style: .function, label: "new line"),
         Spec(title: "+", action: .key(.plus), style: .op, label: "plus")],
    ]

    private func build() {
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 6
        rows.distribution = .fill
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 6),
            rows.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -6),
            rows.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            rows.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -4),
        ])

        let slimRow = row(Self.slim)
        slimRow.heightAnchor.constraint(equalToConstant: 36).isActive = true
        rows.addArrangedSubview(slimRow)
        var first: UIStackView?
        for specs in Self.grid {
            let big = row(specs)
            rows.addArrangedSubview(big)
            if let first { big.heightAnchor.constraint(equalTo: first.heightAnchor).isActive = true }
            first = first ?? big
        }
    }

    private func row(_ specs: [Spec]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: specs.map(button))
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        return stack
    }

    private func button(_ spec: Spec) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = spec.title
        config.cornerStyle = .medium
        let size: CGFloat = spec.style == .digit ? 24 : (spec.title.count > 2 ? 15 : 21)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: size, weight: spec.style == .digit ? .regular : .medium)
            return attributes
        }
        switch spec.style {
        case .digit:
            config.baseBackgroundColor = .secondarySystemGroupedBackground
            config.baseForegroundColor = .label
        case .unit:
            config.baseBackgroundColor = .systemOrange.withAlphaComponent(0.22)
            config.baseForegroundColor = .label
        case .op:
            config.baseBackgroundColor = .tertiarySystemFill
            config.baseForegroundColor = .label
        case .function:
            config.baseBackgroundColor = .systemGray3
            config.baseForegroundColor = .label
        }
        let button = UIButton(configuration: config)
        button.accessibilityLabel = spec.label
        if case .key(.delete) = spec.action {
            button.addAction(UIAction { [weak self] _ in self?.startRepeating() }, for: .touchDown)
            for event: UIControl.Event in [.touchUpInside, .touchUpOutside, .touchCancel] {
                button.addAction(UIAction { [weak self] _ in self?.stopRepeating() }, for: event)
            }
        } else {
            button.addAction(UIAction { [weak self] _ in
                UIDevice.current.playInputClick()
                self?.send(spec.action)
            }, for: .touchUpInside)
        }
        return button
    }

    /// Delete fires once on touch, then repeats while held.
    private func startRepeating() {
        UIDevice.current.playInputClick()
        send(.key(.delete))
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.send(.key(.delete)) }
                }
            }
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

extension KeypadView: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

/// A bar above the letters keyboard with the way back to the keypad.
final class LettersBar: UIInputView {
    init(back: @escaping () -> Void) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 44), inputViewStyle: .keyboard)
        var config = UIButton.Configuration.filled()
        config.title = "123"
        config.baseBackgroundColor = .systemGray3
        config.baseForegroundColor = .label
        config.cornerStyle = .medium
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in back() })
        button.accessibilityLabel = "back to the keypad"
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 72),
            button.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
