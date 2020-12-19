// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  DKAssetGroup.swift
//  DKImagePickerControllerDemo
//
//  Created by ZhangAo on 15/12/13.
//  Copyright © 2015年 ZhangAo. All rights reserved.
//

import Photos

// Group Model
public class DKAssetGroup : NSObject {
	public var groupId: String!
	public var groupName: String!
	public var totalCount: Int!
	
	public var originalCollection: PHAssetCollection!
	public var fetchResult: PHFetchResult<PHAsset>!
    
    /***** BEGIN THREEMA MODIFICATION: add reload data *********/
    public var momentsResult: PHFetchResult<PHAssetCollection>?
    public var momentsLoaded: Bool! = false
    /***** END THREEMA MODIFICATION: add reload data *********/
}
