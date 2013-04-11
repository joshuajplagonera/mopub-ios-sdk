#import "MPGoogleAdMobInterstitialAdapter.h"
#import "MPAdConfigurationFactory.h"
#import "FakeGADInterstitial.h"
#import <CoreLocation/CoreLocation.h>

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(MPGoogleAdMobInterstitialAdapterSpec)

describe(@"MPGoogleAdMobInterstitialAdapter", ^{
    __block id<CedarDouble, MPBaseInterstitialAdapterDelegate> delegate;
    __block MPGoogleAdMobInterstitialAdapter *adapter;
    __block MPAdConfiguration *configuration;
    __block FakeGADInterstitial *interstitial;
    __block CLLocation *location;
    __block GADRequest<CedarDouble> *request;

    beforeEach(^{
        interstitial = [[[FakeGADInterstitial alloc] init] autorelease];
        fakeProvider.fakeGADInterstitial = interstitial.masquerade;
        delegate = nice_fake_for(@protocol(MPBaseInterstitialAdapterDelegate));
        adapter = [[[MPGoogleAdMobInterstitialAdapter alloc] initWithDelegate:delegate] autorelease];
        NSDictionary *headers = @{
                                  kAdTypeHeaderKey: @"admob_full",
                                  kNativeSDKParametersHeaderKey: @"{\"adUnitID\":\"g00g1e\"}"
                                  };
        configuration = [MPAdConfigurationFactory defaultInterstitialConfigurationWithHeaders:headers
                                                                                   HTMLString:nil];

        location = [[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.1, 21.2)
                                                  altitude:11
                                        horizontalAccuracy:12.3
                                          verticalAccuracy:10
                                                 timestamp:[NSDate date]] autorelease];
        delegate stub_method("location").and_return(location);
        request = nice_fake_for([GADRequest class]);
        fakeProvider.fakeGADRequest = request;

        [adapter _getAdWithConfiguration:configuration];
    });

    context(@"when asked to fetch an interstitial", ^{
        it(@"should set interstitial's ad unit ID and delegate", ^{
            interstitial.adUnitID should equal(@"g00g1e");
            interstitial.delegate should equal(adapter);
        });

        it(@"should load the interstitial with a proper request object", ^{
            interstitial.loadedRequest should equal(request);

            request should have_received(@selector(setLocationWithLatitude:longitude:accuracy:)).with(37.1f).and_with(21.2f).and_with(12.3f);
            request should have_received(@selector(setTestDevices:)).with(@[GAD_SIMULATOR_ID]);
        });
    });

    context(@"when asked to show the interstitial", ^{
        __block UIViewController *presentingController;

        beforeEach(^{
            presentingController = [[[UIViewController alloc] init] autorelease];
            [adapter showInterstitialFromViewController:presentingController];
        });

        it(@"should tell the interstitial view controller to show the interstitial", ^{
            interstitial.presentingViewController should equal(presentingController);
        });
    });

    context(@"when the interstitial loads", ^{
        it(@"should tell its delegate", ^{
            [interstitial simulateLoadingAd];
            delegate should have_received(@selector(adapterDidFinishLoadingAd:)).with(adapter);
        });
    });

    context(@"when the interstitial fails to load", ^{
        it(@"should tell its delegate", ^{
            GADRequestError *error = (GADRequestError *)[NSErrorFactory genericError];
            [adapter interstitial:interstitial.masquerade didFailToReceiveAdWithError:error];
            delegate should have_received(@selector(adapter:didFailToLoadAdWithError:)).with(adapter).and_with(error);
        });
    });

    context(@"when the interstitial is about to be presented", ^{
        it(@"should tell its delegate and track an impression", ^{
            [adapter interstitialWillPresentScreen:interstitial.masquerade];
            delegate should have_received(@selector(interstitialWillAppearForAdapter:)).with(adapter);
            delegate should have_received(@selector(interstitialDidAppearForAdapter:)).with(adapter);
            fakeProvider.sharedFakeMPAnalyticsTracker.trackedImpressionConfigurations should contain(configuration);
        });
    });

    context(@"when the interstitial is about to be dismissed", ^{
        it(@"should tell its delegate", ^{
            [adapter interstitialWillDismissScreen:interstitial.masquerade];
            delegate should have_received(@selector(interstitialWillDisappearForAdapter:)).with(adapter);
        });
    });

    context(@"when the interstitial has been dismissed", ^{
        it(@"should tell its delegate", ^{
            [adapter interstitialDidDismissScreen:interstitial.masquerade];
            delegate should have_received(@selector(interstitialDidDisappearForAdapter:)).with(adapter);
        });
    });

    context(@"when the interstitial causes the user to leave the application", ^{
        it(@"should track a click", ^{
            [adapter interstitialWillLeaveApplication:interstitial.masquerade];
            fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should contain(configuration);
        });
    });
});

SPEC_END
