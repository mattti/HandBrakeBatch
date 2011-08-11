//
//  HBBPresets.m
//  HandBrakeBatch
//
//  Created by Cesare Tagliaferri
//  This file is part of the HandBrakeBatch source code.
//  Homepage: <http://www.osomac.com/>.
//  It may be used under the terms of the GNU General Public License.
//

#import "HBBPresets.h"


@implementation HBBPresets
@synthesize presets;

static HBBPresets *instance;

- (id)init
{
    self = [super init];
    if (self) {
        [self initPresets];
    }
    
    return self;
}

- (void)initPresets {
    // Initialize the standard presets, in case there are no custom presets
    NSArray *defaultPresets = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"HandBrakePresets"];
    
    NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] init];
        
    // Default location for HB presets
    NSString *presetPath = [[NSString stringWithString:@"~/Library/Application Support/HandBrake/UserPresets.plist"] stringByExpandingTildeInPath];
    
    // Check if HB's custom presets are present
    // If presets are present, let's parse them
    // Sometimes the "manicure.rb" script returns an empty list. We try 5 times to be sure this won't be visible by the user (unless the preset file is corrupted)
    int retries = 5;
    if ([[NSFileManager defaultManager] fileExistsAtPath:presetPath]) {
        do {
        	// Initialize NSTask
        	NSTask *simpleTask = [[NSTask alloc] init];
        	NSPipe *outputPipe = [NSPipe pipe];
        	[simpleTask setStandardOutput: outputPipe];
        	[simpleTask setStandardError: [simpleTask standardOutput]];
        	[simpleTask setLaunchPath: @"/usr/bin/ruby"];
        	
        	// Get path of manicure.rb
        	NSString *manicure = [[NSBundle mainBundle] pathForResource:@"manicure" ofType:@"rb"];
        	[simpleTask setCurrentDirectoryPath:[manicure stringByDeletingLastPathComponent]];
        	
        	// Build argument array
        	NSArray *arguments = [NSArray arrayWithObjects:manicure, @"-p", nil];
        	[simpleTask setArguments: arguments];
        	
        	// Run task
        	[simpleTask launch];
        	[simpleTask waitUntilExit];
        	
        	NSFileHandle *output = [outputPipe fileHandleForReading];
        	NSData *data = [output availableData];
        	NSString *rawOutput = [NSString stringWithUTF8String:[data bytes]];
        	NSArray *outputLines = [rawOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        	
        	for (NSString *currentLine in outputLines) {
        	    // Ignore empty lines and folders (all preset lines contain a +)
        	    // Only one level of folders is supported
        	    if ([currentLine length] > 4) {
        	        int offset=0;
        	        if ([currentLine characterAtIndex:3] == '+')
        	            offset=3;
        	        
        	        if ([currentLine characterAtIndex:0] == '+' || [currentLine characterAtIndex:3] == '+') {
        	            NSRange separator = [currentLine rangeOfString:@": "];
        	            
        	            NSString *name = [[currentLine substringToIndex:separator.location] substringFromIndex:offset+2];
        	            NSString *args = [currentLine substringFromIndex:separator.location+separator.length];
        	            
        	            [tempDict setObject:args forKey:name];
        	        }
        	    }
        	}
            retries--;
        } while (retries > 0 && [tempDict count] == 0);
    }
    
    // Preset file probably corrupted
    if ( [tempDict count] == 0 ) {
        for (NSString *currentPreset in defaultPresets) {
            [tempDict setObject:[NSString stringWithFormat:@"--preset %@", currentPreset] forKey:currentPreset];
        }
        if (retries == 0)
            NSBeginAlertSheet(@"Unable to read HandBrake custom presets", @"Ok", nil, nil, nil, nil, NULL, NULL, NULL, @"The custom preset file might be corrupted, the application will show the default presets only.");
    }
    
    // Initialize the preset dictionary
    [self setPresets:tempDict];
}

+ (id)hbbPresets {
    
    if(instance)
        return instance;
    
    @synchronized(self)
    {
        instance = [[self alloc] init];
    }
    return instance;
}

@end
