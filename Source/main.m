//
//  main.m
//  gaysailor
//	It's called "gaysailor" cause it makes your dock all rainbow-y.
//	
//  Sholud be run as root so it can overwrite the icons.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

#import "IconFamily.h"

int main (int argc, const char * argv[]) {

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    // Find all the applications in the dock
    NSString *userName = [[[NSProcessInfo processInfo] environment] objectForKey:@"SUDO_USER"];
    NSString *pathToDockPrefs = [NSString stringWithFormat:@"/Users/%@/Library/Preferences/com.apple.dock.plist", userName];
    NSDictionary *dockPrefs = [NSDictionary dictionaryWithContentsOfFile:[pathToDockPrefs stringByExpandingTildeInPath]];
    NSMutableArray *appPaths = [[NSMutableArray alloc] initWithCapacity:10]; 
    for (NSDictionary *itemInfo in [dockPrefs objectForKey:@"persistent-apps"]) {
        NSString *appPath = [[[itemInfo objectForKey:@"tile-data"] objectForKey:@"file-data"] objectForKey:@"_CFURLString"];
        if (appPath) {
            [appPaths addObject:appPath];
        }
    }
    
    NSLog(@"Found all these apps:\n%@", appPaths);
    
    // Crack open the app bundle for each and load the Info.plist
    NSMutableArray *iconFilePaths = [[NSMutableArray alloc] initWithCapacity:10]; 
    for (NSString *appPath in appPaths) {
        NSString *infoPlistPath = [appPath stringByAppendingString:@"Contents/Info.plist"];
        
        // Read the CFBundleIconFile
        NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
        NSString *iconFilePath = [infoPlist objectForKey:@"CFBundleIconFile"];
        iconFilePath = [[iconFilePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"icns"];
        NSString *fullIconPath = [NSString stringWithFormat:@"%@Contents/Resources/%@", appPath, iconFilePath];
        [iconFilePaths addObject:fullIconPath];
        
        // Back that shit up
        NSFileManager *fm = [NSFileManager defaultManager];
		NSError *error = nil;
        [fm copyItemAtPath:fullIconPath toPath:[fullIconPath stringByAppendingPathExtension:@"bak"] error:&error]; 
        
		if (error) {
			NSLog(@"ERROR: Couldn't back up icons. You sure you're running as root? Reason: %@", [error localizedDescription]);
        }
    }
    
    NSLog(@"Found all these icons:\n%@", iconFilePaths);
    
    for (NSString *iconFilePath in iconFilePaths) {
        
        NSLog(@"Working on this icon: %@", iconFilePath);
        
        // Load it up
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:iconFilePath];
        NSData *tiff = [image TIFFRepresentation];
        NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiff];
        CIImage *ciImage = [[CIImage alloc] initWithBitmapImageRep:bitmap];
        
        // Pick a random hue
        CIFilter *hueAdjust = [CIFilter filterWithName:@"CIHueAdjust"];
        [hueAdjust setDefaults];
        [hueAdjust setValue:ciImage forKey:@"inputImage"];
        float hue = (float) (rand() % 6280) / 1000 - 3.14;
        NSLog(@"Hue adjustment angle: %f", hue);
        [hueAdjust setValue:[NSNumber numberWithFloat:hue] forKey:@"inputAngle"];
        
		
        CIImage *newImage = [hueAdjust valueForKey:@"outputImage"];
        NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:newImage];
        NSImage *newNSImage = [[NSImage alloc] initWithSize:NSMakeSize(512, 512)];
        [newNSImage addRepresentation:rep];
		[newImage release];
        
        // Save it out
        IconFamily* iconFamily = [IconFamily iconFamilyWithThumbnailsOfImage:newNSImage
                                                     usingImageInterpolation:NSImageInterpolationHigh];
        [iconFamily writeToFile:iconFilePath];        
		[ciImage release];
    }
	
	[appPaths release];
	[iconFilePaths release];
	
    //system("/usr/bin/killall Dock");
    // Killing the Dock doesn't actually have the intended effect of reloading the icon cache. 
	// You actually have to take the icon out of the dock and relaunch it.
	
    [pool drain];
    return 0;
}

