/*
-----------------------------------------------------------------------------
This source file is part of OGRE
    (Object-oriented Graphics Rendering Engine)
For the latest info, see http://www.ogre3d.org/

Copyright (c) 2000-2014 Torus Knot Software Ltd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
--------------------------------------------------------------------------*/

#include "OgreEAGL2View.h"

#include "OgreRoot.h"
#include "OgreRenderWindow.h"
#include "OgreGLES2RenderSystem.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIDevice.h>

using namespace Ogre;

@implementation EAGL2View

@synthesize mWindowName;

- (NSString *)description
{
    return [NSString stringWithFormat:@"EAGL2View frame dimensions x: %.0f y: %.0f w: %.0f h: %.0f", 
            [self frame].origin.x,
            [self frame].origin.y,
            [self frame].size.width,
            [self frame].size.height];
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (Radian)getFOVForViewPort:(Ogre::Viewport *)viewPort withDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
	static Radian fov;
	static Radian fovp;
	static Radian fovl;
	static bool calcfov = true;

	// TODO: Read the value of rcam from the camera, adding a new property to store the original camera viewport
	Real rcam = 640.0/960.0;
	Real rscr = viewPort->getCamera()->getAspectRatio();

	if (calcfov) {
		// TODO: Add support for other orientations
		//if (viewPort->getOrientationMode() == OR_PORTRAIT)
		{
			if (UIDeviceOrientationIsLandscape(deviceOrientation))
			{
				fov = viewPort->getCamera()->getFOVy();
				if (rscr * rcam < Real(1))
				{
					fovp = fovl = Real(2)*Math::ATan(rscr*rscr*Math::Tan(Real(0.5)*fov));
				}
				else if (rscr > rcam)
				{
					fovl = Real(2)*Math::ATan(rscr/rcam*Math::Tan(Real(0.5)*fov));
					fovp = Real(2)*Math::ATan(rscr*rscr*Math::Tan(Real(0.5)*fov));
				}
				else
				{
					fovp = Real(2)*Math::ATan(rscr*rscr*Math::Tan(Real(0.5)*fov));
					fovl = fov;
				}
			}
			else
			{
				fov = viewPort->getCamera()->getFOVy();
				if (rscr * rcam > Real(1))
				{
					fovp = fov;
					fovl = Real(2)*Math::ATan(rscr*rscr*Math::Tan(Real(0.5)*fov));
				}
				else if (rscr < rcam)
				{
					fovp = fov;
					fovl = Real(2)*Math::ATan(rscr/rcam*Math::Tan(Real(0.5)*fov));
				}
				else
				{
					fovp = fovl = fov;
				}
			}
		}
		calcfov = false;
	}

	if (UIDeviceOrientationIsLandscape(deviceOrientation))
		return fovl;
	else
		return fovp;
}

- (void)layoutSubviews
{
    // Change the viewport orientation based upon the current device orientation.
    // Note: This only operates on the main viewport, usually the main view.

//	This always gets the right orientation
	UIDeviceOrientation deviceOrientation = [[UIApplication sharedApplication] statusBarOrientation];

//	This fails to get a valid orientation sometimes when lauching the application
//	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
//	UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
//	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
//
//	if(!UIDeviceOrientationIsValidInterfaceOrientation(deviceOrientation))
//		return;

    // Check if orientation is supported
    NSString *rotateToOrientation = @"";
    if(deviceOrientation == UIDeviceOrientationPortrait)
        rotateToOrientation = @"UIInterfaceOrientationPortrait";
    else if(deviceOrientation == UIDeviceOrientationPortraitUpsideDown)
        rotateToOrientation = @"UIInterfaceOrientationPortraitUpsideDown";
    else if(deviceOrientation == UIDeviceOrientationLandscapeLeft)
        rotateToOrientation = @"UIInterfaceOrientationLandscapeLeft";
    else if(deviceOrientation == UIDeviceOrientationLandscapeRight)
        rotateToOrientation = @"UIInterfaceOrientationLandscapeRight";

    NSArray *supportedOrientations = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];

    BOOL supported = [supportedOrientations containsObject:rotateToOrientation];

    if (!supported)
        return;

    // Get the window using the name that we saved
    RenderWindow *window = static_cast<RenderWindow *>(Root::getSingleton().getRenderSystem()->getRenderTarget(mWindowName));

    if(window != NULL)
    {
        // Get the window size and initialize temp variables
        unsigned int w = 0, h = 0;
        unsigned int width = (uint)self.bounds.size.width;
        unsigned int height = (uint)self.bounds.size.height;

        if (UIDeviceOrientationIsLandscape(deviceOrientation))
        {
            w = std::max(width, height);
            h = std::min(width, height);
        }
        else
        {
            h = std::max(width, height);
            w = std::min(width, height);
        }

        width = w;
        height = h;

        // Resize the window
        window->resize(width, height);
        
        // After rotation the aspect ratio of the viewport has changed, update that as well.
        if(window->getNumViewports() > 0)
        {
            Ogre::Viewport *viewPort = window->getViewport(0);
            viewPort->getCamera()->setAspectRatio((Real) width / (Real) height);

			Radian fov = [self getFOVForViewPort:viewPort withDeviceOrientation:deviceOrientation];
			viewPort->getCamera()->setFOVy(fov);
       }
    }
}

@end
