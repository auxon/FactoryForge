import Foundation
import UIKit

/// Pre-game PvP lobby: slots, game mode, Ready, Start.
/// Uses LobbySystem for state; UIKit overlay for layout.
final class LobbyMenu: UIPanel_Base {
    private var screenSize: Vector2
    private var closeButton: CloseButton!
    private var titleLabel: UILabel?
    private var slotLabels: [UILabel] = []
    private var readyLabels: [UILabel] = []
    private var addAILabels: [UILabel] = []
    private var modeLabel: UILabel?
    private var modeFFALabel: UILabel?
    private var modeTDMLabel: UILabel?
    private var startLabel: UILabel?
    private var backLabel: UILabel?
    private var scrollView: UIScrollView?

    private let lobby = LobbySystem(config: MatchConfig(maxPlayers: 4))

    var onMatchStart: ((MatchConfig, [LobbySlot]) -> Void)?
    var onBackTapped: (() -> Void)?

    private weak var parentView: UIView?

    init(screenSize: Vector2) {
        self.screenSize = screenSize
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )
        super.init(frame: panelFrame)
        setupCloseButton()
    }

    private func setupCloseButton() {
        let buttonSize: Float = 30 * UIScale
        let buttonX = frame.maxX - 25 * UIScale
        let buttonY = frame.minY + 25 * UIScale
        closeButton = CloseButton(frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)))
        closeButton.onTap = { [weak self] in
            AudioManager.shared.playClickSound()
            self?.onBackTapped?()
        }
    }

    /// Must be called from GameViewController after LobbyMenu is created.
    func setupLabels(in parentView: UIView) {
        self.parentView = parentView
        removeLabels()

        let scale = CGFloat(UIScreen.main.scale)
        let w = CGFloat(screenSize.x) / scale
        let h = CGFloat(screenSize.y) / scale

        // Title
        let title = UILabel(frame: CGRect(x: w * 0.1, y: 60, width: w * 0.8, height: 36))
        title.text = "PvP Lobby"
        title.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        title.textColor = .white
        title.textAlignment = .center
        title.backgroundColor = .clear
        parentView.addSubview(title)
        titleLabel = title

        // Ensure local player in slot 0
        if lobby.slots[0].playerId == nil {
            lobby.joinSlot(0, playerId: 1, displayName: "You", isAI: false)
        }

        // Slots area
        let slotAreaY: CGFloat = 110
        let slotHeight: CGFloat = 44
        let spacing: CGFloat = 8

        for i in 0..<lobby.slots.count {
            let slot = lobby.slots[i]
            let y = slotAreaY + CGFloat(i) * (slotHeight + spacing)

            let slotL = UILabel(frame: CGRect(x: w * 0.1, y: y, width: w * 0.45, height: slotHeight))
            slotL.text = slot.displayName.isEmpty ? "Empty" : slot.displayName
            slotL.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            slotL.textColor = .white
            slotL.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
            slotL.textAlignment = .center
            slotL.layer.cornerRadius = 6
            slotL.clipsToBounds = true
            slotL.isUserInteractionEnabled = false
            parentView.addSubview(slotL)
            slotLabels.append(slotL)

            let readyL = UILabel(frame: CGRect(x: w * 0.58, y: y, width: 56, height: slotHeight))
            readyL.text = slot.isReady ? "Ready ✓" : "Ready"
            readyL.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            readyL.textColor = slot.isReady ? UIColor.systemGreen : .white
            readyL.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
            readyL.textAlignment = .center
            readyL.layer.cornerRadius = 6
            readyL.clipsToBounds = true
            readyL.isUserInteractionEnabled = true
            readyL.tag = i
            let readyTap = UITapGestureRecognizer(target: self, action: #selector(readyTapped(_:)))
            readyL.addGestureRecognizer(readyTap)
            parentView.addSubview(readyL)
            readyLabels.append(readyL)

            let addL = UILabel(frame: CGRect(x: w * 0.68, y: y, width: 70, height: slotHeight))
            addL.text = slot.playerId == nil ? "Add AI" : "—"
            addL.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            addL.textColor = .white
            addL.backgroundColor = slot.playerId == nil ? UIColor(white: 0.25, alpha: 0.9) : UIColor(white: 0.15, alpha: 0.9)
            addL.textAlignment = .center
            addL.layer.cornerRadius = 6
            addL.clipsToBounds = true
            addL.isUserInteractionEnabled = (slot.playerId == nil)
            addL.tag = i
            let addTap = UITapGestureRecognizer(target: self, action: #selector(addAITapped(_:)))
            addL.addGestureRecognizer(addTap)
            parentView.addSubview(addL)
            addAILabels.append(addL)
        }

        // Game mode
        let modeY = slotAreaY + CGFloat(lobby.slots.count) * (slotHeight + spacing) + 24
        let modeT = UILabel(frame: CGRect(x: w * 0.1, y: modeY, width: 100, height: 32))
        modeT.text = "Mode:"
        modeT.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        modeT.textColor = .white
        modeT.backgroundColor = .clear
        parentView.addSubview(modeT)
        modeLabel = modeT

        let ffa = UILabel(frame: CGRect(x: w * 0.28, y: modeY, width: 100, height: 32))
        ffa.text = "Free-for-All"
        ffa.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        ffa.textColor = lobby.config.gameMode == .freeForAll ? UIColor.systemGreen : .white
        ffa.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        ffa.textAlignment = .center
        ffa.layer.cornerRadius = 6
        ffa.clipsToBounds = true
        ffa.isUserInteractionEnabled = true
        let ffaTap = UITapGestureRecognizer(target: self, action: #selector(modeFFATapped))
        ffa.addGestureRecognizer(ffaTap)
        parentView.addSubview(ffa)
        modeFFALabel = ffa

        let tdm = UILabel(frame: CGRect(x: w * 0.52, y: modeY, width: 120, height: 32))
        tdm.text = "Team Deathmatch"
        tdm.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        tdm.textColor = lobby.config.gameMode == .teamDeathmatch ? UIColor.systemGreen : .white
        tdm.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        tdm.textAlignment = .center
        tdm.layer.cornerRadius = 6
        tdm.clipsToBounds = true
        tdm.isUserInteractionEnabled = true
        let tdmTap = UITapGestureRecognizer(target: self, action: #selector(modeTDMTapped))
        tdm.addGestureRecognizer(tdmTap)
        parentView.addSubview(tdm)
        modeTDMLabel = tdm

        // Start & Back
        let btnY = modeY + 50
        let btnW: CGFloat = 100
        let btnH: CGFloat = 40

        startLabel = createActionLabel(title: "Start", frame: CGRect(x: w * 0.1, y: btnY, width: btnW, height: btnH), parent: parentView)
        let startTap = UITapGestureRecognizer(target: self, action: #selector(startTapped))
        startLabel?.addGestureRecognizer(startTap)
        updateStartEnabled()

        backLabel = createActionLabel(title: "Back", frame: CGRect(x: w * 0.1 + btnW + 16, y: btnY, width: btnW, height: btnH), parent: parentView)
        let backTap = UITapGestureRecognizer(target: self, action: #selector(backTapped))
        backLabel?.addGestureRecognizer(backTap)
    }

    private func createActionLabel(title: String, frame: CGRect, parent: UIView) -> UILabel {
        let l = UILabel(frame: frame)
        l.text = title
        l.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        l.textColor = .white
        l.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        l.textAlignment = .center
        l.layer.cornerRadius = 6
        l.clipsToBounds = true
        l.isUserInteractionEnabled = true
        parent.addSubview(l)
        return l
    }

    private func updateStartEnabled() {
        let canStart = lobby.canStartMatch()
        startLabel?.alpha = canStart ? 1.0 : 0.5
        startLabel?.isUserInteractionEnabled = canStart
    }

    private func refreshSlotLabels() {
        for (i, slot) in lobby.slots.enumerated() {
            if i < slotLabels.count {
                slotLabels[i].text = slot.displayName.isEmpty ? "Empty" : slot.displayName
            }
            if i < readyLabels.count {
                readyLabels[i].text = slot.isReady ? "Ready ✓" : "Ready"
                readyLabels[i].textColor = slot.isReady ? UIColor.systemGreen : .white
                readyLabels[i].isUserInteractionEnabled = !slot.isAI
            }
            if i < addAILabels.count {
                addAILabels[i].text = slot.playerId == nil ? "Add AI" : "—"
                addAILabels[i].backgroundColor = slot.playerId == nil ? UIColor(white: 0.25, alpha: 0.9) : UIColor(white: 0.15, alpha: 0.9)
                addAILabels[i].isUserInteractionEnabled = (slot.playerId == nil)
            }
        }
        modeFFALabel?.textColor = lobby.config.gameMode == .freeForAll ? UIColor.systemGreen : .white
        modeTDMLabel?.textColor = lobby.config.gameMode == .teamDeathmatch ? UIColor.systemGreen : .white
        updateStartEnabled()
    }

    @objc private func readyTapped(_ g: UITapGestureRecognizer) {
        guard let v = g.view, v.tag >= 0, v.tag < lobby.slots.count else { return }
        let i = v.tag
        let slot = lobby.slots[i]
        guard !slot.isAI else { return }
        AudioManager.shared.playClickSound()
        lobby.setReady(i, ready: !slot.isReady)
        refreshSlotLabels()
    }

    @objc private func addAITapped(_ g: UITapGestureRecognizer) {
        guard let v = g.view, v.tag >= 0, v.tag < lobby.slots.count else { return }
        let i = v.tag
        guard lobby.slots[i].playerId == nil else { return }
        AudioManager.shared.playClickSound()
        let aiId = UInt32(2 + i)
        lobby.joinSlot(i, playerId: aiId, displayName: "AI", isAI: true)
        lobby.setReady(i, ready: true)
        refreshSlotLabels()
    }

    @objc private func modeFFATapped() {
        AudioManager.shared.playClickSound()
        lobby.setGameMode(.freeForAll)
        refreshSlotLabels()
    }

    @objc private func modeTDMTapped() {
        AudioManager.shared.playClickSound()
        lobby.setGameMode(.teamDeathmatch)
        refreshSlotLabels()
    }

    @objc private func startTapped() {
        guard lobby.canStartMatch() else { return }
        AudioManager.shared.playClickSound()
        lobby.startMatch()
    }

    @objc private func backTapped() {
        AudioManager.shared.playClickSound()
        onBackTapped?()
    }

    private func removeLabels() {
        titleLabel?.removeFromSuperview()
        titleLabel = nil
        for l in slotLabels { l.removeFromSuperview() }
        slotLabels.removeAll()
        for l in readyLabels { l.removeFromSuperview() }
        readyLabels.removeAll()
        for l in addAILabels { l.removeFromSuperview() }
        addAILabels.removeAll()
        modeLabel?.removeFromSuperview()
        modeLabel = nil
        modeFFALabel?.removeFromSuperview()
        modeFFALabel = nil
        modeTDMLabel?.removeFromSuperview()
        modeTDMLabel = nil
        startLabel?.removeFromSuperview()
        startLabel = nil
        backLabel?.removeFromSuperview()
        backLabel = nil
    }

    override func open() {
        super.open()
        lobby.reset()
        lobby.joinSlot(0, playerId: 1, displayName: "You", isAI: false)
        // setupLabels(in:) called by GameViewController after opening
    }

    override func close() {
        super.close()
        removeLabels()
    }

    override func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }
        if closeButton.handleTap(at: position) { return true }
        return true
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }
        super.render(renderer: renderer)
        closeButton.render(renderer: renderer)
    }

    /// Call from GameViewController to wire match start. LobbySystem.startMatch() invokes onMatchStart.
    func setMatchStartHandler(_ handler: @escaping (MatchConfig, [LobbySlot]) -> Void) {
        lobby.onMatchStart = handler
    }
}
