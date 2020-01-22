//
//  CRSegmentedControl.swift
//  CRSegmentedControl
//
//  Created by WaqasAli on 16/01/2020.
//  Copyright © 2020 CamelRider. All rights reserved.
//

import UIKit

@objc
public enum ScrollableSegmentedControlSegmentStyle: Int {
    case textOnly, imageOnly, imageOnTop, imageOnLeft
}

/**
 A ScrollableSegmentedControl object is horizontaly scrollable control made of multiple segments, each segment functioning as discrete button.
 */
@IBDesignable
public class CRSegmentedControl: UIControl {

    let flowLayout = UICollectionViewFlowLayout()
    var collectionView:UICollectionView?
    var collectionViewController:CRCollectionVC?
    var segmentsData = [CRSegmentData]()
    var longestTextWidth:CGFloat = 10
    
    fileprivate var normalAttributes:[NSAttributedString.Key : Any]?
    fileprivate var highlightedAttributes:[NSAttributedString.Key : Any]?
    fileprivate var selectedAttributes:[NSAttributedString.Key : Any]?
    fileprivate var _titleAttributes:[UInt: [NSAttributedString.Key : Any]] = [UInt: [NSAttributedString.Key : Any]]()
    
    /**
     The index number identifying the selected segment (that is, the last segment touched).
     
     Set this property to -1 to turn off the current selection.
     */
    @objc public var selectedSegmentIndex: Int = -1 {
        didSet{
            if selectedSegmentIndex < -1 {
                selectedSegmentIndex = -1
            } else if selectedSegmentIndex > segmentsData.count - 1 {
                selectedSegmentIndex = segmentsData.count - 1
            }
            
            if selectedSegmentIndex >= 0 {
                var scrollPossition:UICollectionView.ScrollPosition = .bottom
                let indexPath = IndexPath(item: selectedSegmentIndex, section: 0)
                if let atribs = collectionView?.layoutAttributesForItem(at: indexPath) {
                    let frame = atribs.frame
                    if frame.origin.x < collectionView!.contentOffset.x {
                        scrollPossition = .left
                    } else if frame.origin.x + frame.size.width > (collectionView!.frame.size.width + collectionView!.contentOffset.x) {
                        scrollPossition = .right
                    }
                }
            
                collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: scrollPossition)
            } else {
                if let indexPath = collectionView?.indexPathsForSelectedItems?.first {
                    collectionView?.deselectItem(at: indexPath, animated: true)
                }
            }
            
            if oldValue != selectedSegmentIndex {
                self.sendActions(for: .valueChanged)
            }
        }
    }
    
    /**
     A Boolean value that determines if the width of all segments is going to be fixed or not.
     
     When this value is set to true all segments have the same width which equivalent of the width required to display the text that requires the longest width to be drawn.
     The default value is true.
     */
    public var fixedSegmentWidth: Bool = true {
        didSet {
            if oldValue != fixedSegmentWidth {
                setNeedsLayout()
            }
        }
    }
    
    
    @objc public var segmentStyle:ScrollableSegmentedControlSegmentStyle = .textOnly {
        didSet {
            if oldValue != segmentStyle {
                if let collectionView_ = collectionView {
                    let nilCellClass:AnyClass? = nil
                    // unregister the old cell
                    switch oldValue {
                    case .textOnly:
                        collectionView_.register(nilCellClass, forCellWithReuseIdentifier: CRCollectionVC.textOnlyCellIdentifier)
                    case .imageOnly:
                        collectionView_.register(nilCellClass, forCellWithReuseIdentifier: CRCollectionVC.imageOnlyCellIdentifier)
                    case .imageOnTop:
                        collectionView_.register(nilCellClass, forCellWithReuseIdentifier: CRCollectionVC.imageOnTopCellIdentifier)
                    case .imageOnLeft:
                        collectionView_.register(nilCellClass, forCellWithReuseIdentifier: CRCollectionVC.imageOnLeftCellIdentifier)
                    }

                    // register the new cell
                    switch segmentStyle {
                    case .textOnly:
                        collectionView_.register(CRTextOnlySegmentedCell.self, forCellWithReuseIdentifier: CRCollectionVC.textOnlyCellIdentifier)
                    case .imageOnly:
                        collectionView_.register(CRImageSegmentedCell.self, forCellWithReuseIdentifier: CRCollectionVC.imageOnlyCellIdentifier)
                    case .imageOnTop:
                        collectionView_.register(CRImageOnTopCell.self, forCellWithReuseIdentifier: CRCollectionVC.imageOnTopCellIdentifier)
                    case .imageOnLeft:
                        collectionView_.register(CRImageOnLeftCell.self, forCellWithReuseIdentifier: CRCollectionVC.imageOnLeftCellIdentifier)
                    }
                    
                    let indexPath = collectionView?.indexPathsForSelectedItems?.last
                    
                    setNeedsLayout()
                    
                    if indexPath != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
                            self.collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: .left)
                        })
                    }
                }
            }
        }
    }
    
    override public var tintColor: UIColor! {
        didSet {
            collectionView?.tintColor = tintColor
            reloadSegments()
        }
    }
    
    fileprivate var _segmentContentColor:UIColor?
    @objc public dynamic var segmentContentColor:UIColor? {
        get { return _segmentContentColor }
        set {
            _segmentContentColor = newValue
            reloadSegments()
        }
    }

    fileprivate var _underlineHeight: CGFloat = 4.0
    @objc public dynamic var underlineHeight: CGFloat {
        get { return _underlineHeight }
        set {
            if newValue != _underlineHeight {
                _underlineHeight = newValue
                reloadSegments()
            }
        }
    }
    
    fileprivate var _selectedSegmentContentColor:UIColor?
    @objc public dynamic var selectedSegmentContentColor:UIColor? {
        get { return _selectedSegmentContentColor }
        set {
            _selectedSegmentContentColor = newValue
            reloadSegments()
        }
    }
    
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
    @objc public func setTitleTextAttributes(_ attributes: [NSAttributedString.Key : Any]?, for state: UIControl.State) {
        _titleAttributes[state.rawValue] = attributes
        
        normalAttributes = _titleAttributes[UIControl.State.normal.rawValue]
        highlightedAttributes = _titleAttributes[UIControl.State.highlighted.rawValue]
        selectedAttributes = _titleAttributes[UIControl.State.selected.rawValue]
        
        for segment in segmentsData {
            configureAttributedTitlesForSegment(segment)
            
            if let title = segment.title {
                calculateLongestTextWidth(text: title)
            }
        }
        
        flowLayout.invalidateLayout()
        reloadSegments()
    }
    
    private func configureAttributedTitlesForSegment(_ segment:CRSegmentData) {
        segment.normalAttributedTitle = nil
        segment.highlightedAttributedTitle = nil
        segment.selectedAttributedTitle = nil
        
        if let title = segment.title {
            if normalAttributes != nil {
                segment.normalAttributedTitle = NSAttributedString(string: title, attributes: normalAttributes!)
            }
            
            if highlightedAttributes != nil {
                segment.highlightedAttributedTitle = NSAttributedString(string: title, attributes: highlightedAttributes!)
            } else {
                if selectedAttributes != nil {
                    segment.highlightedAttributedTitle = NSAttributedString(string: title, attributes: selectedAttributes!)
                } else {
                    if normalAttributes != nil {
                        segment.highlightedAttributedTitle = NSAttributedString(string: title, attributes: normalAttributes!)
                    }
                }
            }
            
            if selectedAttributes != nil {
                segment.selectedAttributedTitle = NSAttributedString(string: title, attributes: selectedAttributes!)
            } else {
                if highlightedAttributes != nil {
                    segment.selectedAttributedTitle = NSAttributedString(string: title, attributes: highlightedAttributes!)
                } else {
                    if normalAttributes != nil {
                        segment.selectedAttributedTitle = NSAttributedString(string: title, attributes: normalAttributes!)
                    }
                }
            }
        }
    }
    
    @objc public func titleTextAttributes(for state: UIControl.State) -> [NSAttributedString.Key : Any]? {
        return _titleAttributes[state.rawValue]
    }
    
    // MARK: - Managing Segments
    
    /**
     Inserts a segment at a specific position in the receiver and gives it a title as content.
     */
    @objc public func insertSegment(withTitle title: String, at index: Int) {
        let segment = CRSegmentData()
        segment.title = title
        configureAttributedTitlesForSegment(segment)
        segmentsData.insert(segment, at: index)
        calculateLongestTextWidth(text: title)
        reloadSegments()
    }
    
    /**
     Inserts a segment at a specified position in the receiver and gives it an image as content.
     */
    @objc public func insertSegment(with image: UIImage, at index: Int) {
        let segment = CRSegmentData()
        segment.image = image.withRenderingMode(.alwaysTemplate)
        segmentsData.insert(segment, at: index)
        reloadSegments()
    }
    
    /**
     Inserts a segment at a specific position in the receiver and gives it a title as content and/or image as content.
     */
    @objc public func insertSegment(withTitle title: String?, image: UIImage?, at index: Int) {
        let segment = CRSegmentData()
        segment.title = title
        segment.image = image?.withRenderingMode(.alwaysTemplate)
        segmentsData.insert(segment, at: index)
        
        if let str = title {
            calculateLongestTextWidth(text: str)
        }
        reloadSegments()
    }
    
    /**
     Removes segment at a specific position from the receiver.
     */
    @objc public func removeSegment(at index: Int){
        segmentsData.remove(at: index)
        if(selectedSegmentIndex == index) {
            selectedSegmentIndex = selectedSegmentIndex - 1
        } else if(selectedSegmentIndex > segmentsData.count) {
            selectedSegmentIndex = -1
        }
        reloadSegments()
    }
    
    /**
     Returns the number of segments the receiver has.
     */
    @objc public var numberOfSegments: Int { return segmentsData.count }
    
    /**
     Returns the title of the specified segment.
     */
    @objc public func titleForSegment(at segment: Int) -> String? {
        if segmentsData.count == 0 {
            return nil
        }
        
        return safeSegmentData(forIndex: segment).title
    }
    
    /**
     Configure if the selected segment should have underline. Default value is false.
     */
    @IBInspectable
    @objc public var underlineSelected:Bool = false
    
    // MARK: - Layout management
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        guard let collectionView_ = collectionView else {
            return
        }
        
        collectionView_.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        collectionView_.contentOffset = CGPoint(x: 0, y: 0)
        collectionView_.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        flowLayout.invalidateLayout()
        configureSegmentSize()
        reloadSegments()
    }
    
    // MARK: - Private
    
    fileprivate func configure() {
        clipsToBounds = true
        
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 0
        
        collectionView = UICollectionView(frame: frame, collectionViewLayout: flowLayout)
        collectionView!.tag = 1
        collectionView!.tintColor = tintColor
        collectionView!.register(CRTextOnlySegmentedCell.self, forCellWithReuseIdentifier: CRCollectionVC.textOnlyCellIdentifier)
        collectionViewController = CRCollectionVC(segmentedControl: self)
        collectionView!.dataSource = collectionViewController
        collectionView!.delegate = collectionViewController
        collectionView!.backgroundColor = UIColor.clear
        collectionView!.showsHorizontalScrollIndicator = false
        
        self.layer.cornerRadius = 12
        self.layer.shadowColor = UIColor.lightGray.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 0)
        self.layer.shadowRadius = 1
        self.layer.shadowOpacity = 1
        self.layer.masksToBounds = true
        
        addSubview(collectionView!)
    }
    
    fileprivate func configureSegmentSize() {
        let width:CGFloat
        
        if fixedSegmentWidth == true {
            switch segmentStyle {
            case .imageOnLeft:
                width = longestTextWidth + CRBaseSegmentedCell.imageSize + CRBaseSegmentedCell.imageToTextMargin * 2
            default:
                if collectionView!.frame.size.width > longestTextWidth * CGFloat(segmentsData.count) {
                    width = collectionView!.frame.size.width / CGFloat(segmentsData.count)
                } else {
                    width = longestTextWidth
                }
            }
            
            flowLayout.estimatedItemSize = CGSize()
            flowLayout.itemSize = CGSize(width: width, height: frame.size.height)
        } else {
            width = 1.0
            flowLayout.itemSize = CGSize(width: width, height: frame.size.height)
            flowLayout.estimatedItemSize = CGSize(width: width, height: frame.size.height)
        }
    }
    
    fileprivate func calculateLongestTextWidth(text:String) {
        let fontAttributes:[NSAttributedString.Key:Any]
        if normalAttributes != nil {
            fontAttributes = normalAttributes!
        } else  if highlightedAttributes != nil {
            fontAttributes = highlightedAttributes!
        } else if selectedAttributes != nil {
            fontAttributes = selectedAttributes!
        } else {
            fontAttributes =  [NSAttributedString.Key.font: CRBaseSegmentedCell.defaultFont]
        }
        
        let size = (text as NSString).size(withAttributes: fontAttributes)
        let newLongestTextWidth = 2.0 + size.width + CRBaseSegmentedCell.textPadding * 2
        if newLongestTextWidth > longestTextWidth {
            longestTextWidth = newLongestTextWidth
            configureSegmentSize()
        }
    }
    
    private func safeSegmentData(forIndex index:Int) -> CRSegmentData {
        let segmentData:CRSegmentData
        
        if index <= 0 {
            segmentData = segmentsData[0]
        } else if index >= segmentsData.count {
            segmentData = segmentsData[segmentsData.count - 1]
        } else {
            segmentData = segmentsData[index]
        }
        
        return segmentData
    }
    
    fileprivate func reloadSegments() {
        if let collectionView_ = collectionView {
            collectionView_.reloadData()
            if selectedSegmentIndex >= 0 {
                let indexPath = IndexPath(item: selectedSegmentIndex, section: 0)
                collectionView_.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
            }
        }
    }
}
