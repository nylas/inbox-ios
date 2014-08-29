//
//  INUploadFileTask.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/21/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INUploadFileTask.h"
#import "INDatabaseManager.h"
#import "INFile.h"
#import "INDraft.h"

@implementation INUploadFileTask

- (void)applyLocally
{
	[[INDatabaseManager shared] persistModel: self.model];
}

- (void)rollbackLocally
{
	[[INDatabaseManager shared] unpersistModel:self.model willResaveSameModel:NO];
}

- (NSURLRequest *)buildAPIRequest
{
	INFile * file = (INFile *)self.model;
	
    NSAssert(file, @"INUploadFileTask asked to buildRequest with no model!");
	NSAssert([file namespaceID], @"INUploadFileTask asked to buildRequest with no namespace!");
	NSAssert([file localDataPath], @"INUploadFileTask asked to upload a file with no local data.");
	
    NSString * path = [NSString stringWithFormat:@"/n/%@/files", [file namespaceID]];
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].AF.baseURL] absoluteString];

	return [[[[INAPIManager shared] AF] requestSerializer] multipartFormRequestWithMethod:@"POST" URLString:url parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
		NSURL * fileURL = [NSURL fileURLWithPath: [file localDataPath]];
		[formData appendPartWithFileURL:fileURL name:@"file" fileName:[file filename] mimeType:[file mimetype] error:NULL];
	} error:NULL];
}

- (NSMutableArray *)waitingDrafts
{
    if (!self.data[@"waitingDrafts"])
        [self.data setObject:[NSMutableArray array] forKey:@"waitingDrafts"];
    return self.data[@"waitingDrafts"];
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    if ([responseObject isKindOfClass: [NSArray class]])
        responseObject = [responseObject firstObject];
    
    if (![responseObject isKindOfClass: [NSDictionary class]])
        return NSLog(@"SaveDraft weird response: %@", responseObject);

    NSString * oldID = [self.model ID];

 	INFile * file = (INFile *)self.model;
    [[INDatabaseManager shared] unpersistModel: file willResaveSameModel:YES];
	[file updateWithResourceDictionary: responseObject];
	[[INDatabaseManager shared] persistModel: file];
	
	for (INDraft * draft in [self waitingDrafts])
        [draft fileWithID:oldID uploadedAs:[self.model ID]];
}

@end
