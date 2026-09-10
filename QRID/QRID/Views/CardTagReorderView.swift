import SwiftUI
import UIKit

// A collection owns its drag sessions so Form cannot lift the entire containing row.
struct CardTagReorderView: UIViewRepresentable {
    let tags: [String]
    let colorOverrides: [String: CardTagColorOverride]
    let onReorder: ([String]) -> Void
    let onRemove: (String) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> TagCollectionView {
        let layout = LeadingTagFlowLayout()
        layout.minimumInteritemSpacing = 7
        layout.minimumLineSpacing = 6
        let collection = TagCollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.isScrollEnabled = false
        collection.contentInsetAdjustmentBehavior = .never
        collection.dragInteractionEnabled = true
        collection.allowsSelection = false
        collection.dataSource = context.coordinator
        collection.delegate = context.coordinator
        collection.dragDelegate = context.coordinator
        collection.dropDelegate = context.coordinator
        collection.register(TagCell.self, forCellWithReuseIdentifier: "tag")
        collection.accessibilityIdentifier = "selected-tags"
        return collection
    }

    func updateUIView(_ collection: TagCollectionView, context: Context) {
        let coordinator = context.coordinator
        let palette = tags.map { CardTagColorPalette.colorStyle(for: $0, overrides: colorOverrides).segmentHexes }
        let changed = coordinator.parent.tags != tags || coordinator.parent.colorOverrides != colorOverrides
            || coordinator.renderedPalette != palette
            || coordinator.font.pointSize != Coordinator.tagFont.pointSize
        coordinator.parent = self
        coordinator.renderedPalette = palette
        coordinator.font = Coordinator.tagFont
        if changed {
            collection.reloadData()
            collection.collectionViewLayout.invalidateLayout()
            collection.invalidateIntrinsicContentSize()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: TagCollectionView, context: Context) -> CGSize? {
        let width = max(1, proposal.width ?? 320)
        if uiView.bounds.width != width {
            uiView.bounds.size.width = width
            uiView.collectionViewLayout.invalidateLayout()
        }
        uiView.layoutIfNeeded()
        return CGSize(width: width, height: uiView.collectionViewLayout.collectionViewContentSize.height)
    }

    final class TagCollectionView: UICollectionView {
        override var contentSize: CGSize {
            didSet { if oldValue.height != contentSize.height { invalidateIntrinsicContentSize() } }
        }
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
        }
    }

    // Flow layout normally spreads a full row across its width. Tags keep a fixed gap instead.
    final class LeadingTagFlowLayout: UICollectionViewFlowLayout {
        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            super.layoutAttributesForElements(in: rect)?.map { attributes in
                guard attributes.representedElementCategory == .cell else { return attributes }
                return layoutAttributesForItem(at: attributes.indexPath) ?? attributes
            }
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            guard let attributes = super.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else { return nil }
            var leading = sectionInset.left
            for item in stride(from: indexPath.item - 1, through: 0, by: -1) {
                guard let previous = super.layoutAttributesForItem(at: IndexPath(item: item, section: indexPath.section)),
                      abs(previous.frame.midY - attributes.frame.midY) < 1 else { break }
                leading += previous.frame.width + minimumInteritemSpacing
            }
            attributes.frame.origin.x = leading
            return attributes
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            newBounds.width != collectionView?.bounds.width || super.shouldInvalidateLayout(forBoundsChange: newBounds)
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                             UICollectionViewDragDelegate, UICollectionViewDropDelegate {
        var parent: CardTagReorderView
        var renderedPalette: [[String]] = []
        var font = tagFont
        static var tagFont: UIFont {
            .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .semibold)
        }

        init(_ parent: CardTagReorderView) { self.parent = parent }

        func font(for tag: String) -> UIFont {
            let weight: UIFont.Weight
            switch CardTagColorPalette.textWeight(for: tag, overrides: parent.colorOverrides) {
            case .regular: weight = .regular
            case .medium: weight = .semibold
            case .bold: weight = .heavy
            }
            return .systemFont(ofSize: font.pointSize, weight: weight)
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.tags.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tag", for: indexPath) as! TagCell
            let tag = parent.tags[indexPath.item]
            cell.configure(tag: tag, style: CardTagColorPalette.colorStyle(for: tag, overrides: parent.colorOverrides), font: font(for: tag))
            cell.onRemove = { [weak self] in self?.parent.onRemove(tag) }
            cell.label.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: L.tagMoveUp) { [weak self] _ in self?.move(tag, by: -1) ?? false },
                UIAccessibilityCustomAction(name: L.tagMoveDown) { [weak self] _ in self?.move(tag, by: 1) ?? false },
            ]
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                            sizeForItemAt indexPath: IndexPath) -> CGSize {
            let font = font(for: parent.tags[indexPath.item])
            let titleWidth = (parent.tags[indexPath.item] as NSString).size(withAttributes: [.font: font]).width
            return CGSize(width: min(collectionView.bounds.width, ceil(titleWidth) + 34), height: ceil(font.lineHeight) + 10)
        }

        func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession,
                            at indexPath: IndexPath) -> [UIDragItem] {
            guard parent.tags.count > 1 else { return [] }
            let tag = parent.tags[indexPath.item]
            let item = UIDragItem(itemProvider: NSItemProvider(object: tag as NSString))
            item.localObject = tag
            session.localContext = self
            return [item]
        }

        func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool { true }

        func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
            guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
            let preview = UIDragPreviewParameters()
            preview.backgroundColor = .clear
            preview.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: cell.bounds.height / 2)
            return preview
        }

        func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
            session.localDragSession?.localContext as? Coordinator === self
        }

        func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession,
                            withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
            guard session.localDragSession?.localContext as? Coordinator === self else {
                return UICollectionViewDropProposal(operation: .forbidden)
            }
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
            guard let item = coordinator.items.first, let source = item.sourceIndexPath,
                  let tag = item.dragItem.localObject as? String,
                  parent.tags.indices.contains(source.item), parent.tags[source.item] == tag else { return }
            let destination = IndexPath(item: min(coordinator.destinationIndexPath?.item ?? parent.tags.count - 1,
                                                   parent.tags.count - 1), section: 0)
            var reordered = parent.tags
            reordered.remove(at: source.item)
            reordered.insert(tag, at: destination.item)
            // Update the data source before UIKit applies its item-level move animation.
            parent = CardTagReorderView(tags: reordered, colorOverrides: parent.colorOverrides,
                                       onReorder: parent.onReorder, onRemove: parent.onRemove)
            collectionView.performBatchUpdates {
                collectionView.deleteItems(at: [source])
                collectionView.insertItems(at: [destination])
            }
            coordinator.drop(item.dragItem, toItemAt: destination)
            parent.onReorder(reordered)
        }

        private func move(_ tag: String, by offset: Int) -> Bool {
            guard let from = parent.tags.firstIndex(of: tag), parent.tags.indices.contains(from + offset) else { return false }
            var reordered = parent.tags
            reordered.swapAt(from, from + offset)
            parent.onReorder(reordered)
            return true
        }
    }

    final class TagCell: UICollectionViewCell {
        let label = UILabel()
        private let removeButton = UIButton(type: .system)
        private let background = CAGradientLayer()
        var onRemove: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            background.startPoint = CGPoint(x: 0, y: 0.5)
            background.endPoint = CGPoint(x: 1, y: 0.5)
            background.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
            background.borderWidth = 1
            background.masksToBounds = true
            contentView.layer.insertSublayer(background, at: 0)
            contentView.addSubview(label)
            contentView.addSubview(removeButton)
            label.lineBreakMode = .byTruncatingTail
            label.isAccessibilityElement = true
            removeButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)), for: .normal)
            removeButton.addTarget(self, action: #selector(removeTag), for: .touchUpInside)
            isAccessibilityElement = false
            accessibilityElements = [label, removeButton]
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func configure(tag: String, style: CardTagColorStyle, font: UIFont) {
            label.font = font
            let ink = style.ink
            label.textColor = ink.white ? .white : .black
            label.attributedText = nil
            label.text = tag
            label.layer.shadowColor = (ink.white ? UIColor.black : UIColor.white).cgColor
            label.layer.shadowOffset = .zero
            label.layer.shadowRadius = 0.8
            label.layer.shadowOpacity = ink.outlined ? 0.8 : 0
            label.accessibilityIdentifier = "tag-label-" + tag
            removeButton.tintColor = label.textColor
            removeButton.accessibilityLabel = "\(L.delete) \(tag)"
            removeButton.accessibilityIdentifier = "tag-remove-" + tag
            accessibilityIdentifier = "tag-chip-" + tag
            let colors = style.segmentHexes
            let cgColors: [CGColor] = colors.flatMap { hex -> [CGColor] in
                let color = UIColor(Color(hex: hex)).withAlphaComponent(0.86).cgColor
                return [color, color]
            }
            background.colors = cgColors
            background.locations = colors.indices.flatMap { index in
                [NSNumber(value: Double(index) / Double(colors.count)), NSNumber(value: Double(index + 1) / Double(colors.count))]
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            background.frame = contentView.bounds
            background.cornerRadius = bounds.height / 2
            CATransaction.commit()
            label.frame = CGRect(x: 8, y: 0, width: max(0, bounds.width - 34), height: bounds.height)
            removeButton.frame = CGRect(x: bounds.width - 24, y: 0, width: 24, height: bounds.height)
        }

        @objc private func removeTag() { onRemove?() }
    }
}
