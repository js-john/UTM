//
// Copyright © 2020 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "UIViewController+Extensions.h"
#import "VMCursor.h"
#import "VMDisplayMetalViewController+Gamepad.h"
#import "VMDisplayMetalViewController+Touch.h"
#import "CSDisplayMetal.h"
#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"

@implementation VMDisplayMetalViewController(Gamepad)

- (void)initGamepad {
    // notifications for controller (dis)connect
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerWasConnected:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerWasDisconnected:) name:GCControllerDidDisconnectNotification object:nil];
    for (GCController *controller in [GCController controllers]) {
        [self setupController:controller];
    }
}

#pragma mark - Gamepad connection

- (void)controllerWasConnected:(NSNotification *)notification {
    // a controller was connected
    GCController *controller = (GCController *)notification.object;
    NSLog(@"Controller connected: %@", controller.vendorName);
    [self setupController:controller];
}

- (void)controllerWasDisconnected:(NSNotification *)notification {
    // a controller was disconnected
    GCController *controller = (GCController *)notification.object;
    NSLog(@"Controller disconnected: %@", controller.vendorName);
    [_gamepadMouseTimer invalidate];
    _gamepadMouseTimer = nil;
}

- (void)setupController:(GCController *)controller {
    GCExtendedGamepad *gamepad = controller.extendedGamepad;
    __weak typeof(self) _self = self;
    _controller = controller;
    NSLog(@"active controller switched to: %@", controller.vendorName);
    
    gamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonTriggerLeft" pressed:pressed];
    };
    
    gamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonTriggerRight" pressed:pressed];
    };
    
    gamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonShoulderLeft" pressed:pressed];
    };
    
    gamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonShoulderRight" pressed:pressed];
    };
    
    gamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonA" pressed:pressed];
    };
    
    gamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonB" pressed:pressed];
    };
    
    gamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonX" pressed:pressed];
    };
    
    gamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonY" pressed:pressed];
    };
    
    gamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonDpadUp" pressed:pressed];
    };
    
    gamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonDpadLeft" pressed:pressed];
    };
    
    gamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonDpadDown" pressed:pressed];
    };
    
    gamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [_self gamepadButton:@"GCButtonDpadRight" pressed:pressed];
    };
    
    gamepad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad * _Nonnull dpad, float xValue, float yValue) {
        VMDisplayMetalViewController *s = _self;
        s -> _gamepadleftStickY = yValue;
    };
    
    gamepad.rightThumbstick.valueChangedHandler = ^(GCControllerDirectionPad * _Nonnull dpad, float xValue, float yValue) {
        VMDisplayMetalViewController *s = _self;
        s -> _gamepadRightStickX = xValue;
        s -> _gamepadRightStickY = yValue;
    };
    
    if (@available(iOS 13.0, *)) {
        gamepad.buttonMenu.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
            [_self gamepadButton:@"GCButtonMenu" pressed:pressed];
        };
    }
    
    if (!_gamepadMouseTimer) {
        _gamepadMouseTimer = [NSTimer scheduledTimerWithTimeInterval:0.016 target:self selector:@selector(mouseThread) userInfo:nil repeats:YES];
    }
    
}

- (void)mouseThread {
    if (_gamepadRightStickY != 0 || _gamepadRightStickX != 0) {
        CGPoint center = _cursor.center;
        NSInteger speed = [self integerForSetting:@"GCThumbstickRightSpeed"];
        [_cursor startMovement:center];
        [_cursor updateMovement:CGPointMake(center.x + _gamepadRightStickX * speed, center.y - _gamepadRightStickY * speed)];
    }
    if (_gamepadleftStickY != 0) {
        [self.vmInput sendMouseScroll:_gamepadleftStickY > 0 ? SEND_SCROLL_UP : SEND_SCROLL_DOWN button: self.mouseButtonDown dy:0];
    }
}

- (void)gamepadButton:(NSString *)identifier pressed:(BOOL)isPressed {
    NSInteger value = [self integerForSetting:identifier];
    NSLog(@"GC button %@ (%ld) pressed:%d", identifier, value, isPressed);
    switch (value) {
        case 0:
            break;
        case -1:
            [self.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:isPressed point:CGPointZero];
            _mouseLeftDown = isPressed;
            break;
        case -3:
            [self.vmInput sendMouseButton:SEND_BUTTON_RIGHT pressed:isPressed point:CGPointZero];
            _mouseRightDown = isPressed;
            break;
        case -2:
            [self.vmInput sendMouseButton:SEND_BUTTON_MIDDLE pressed:isPressed point:CGPointZero];
            _mouseMiddleDown = isPressed;
            break;
        default:
            [self sendExtendedKey:isPressed ? SEND_KEY_PRESS : SEND_KEY_RELEASE code:(int)value];
            break;
    }
}

@end
