You probably can’t reliably ship the **same feature set** on the public App Store by only changing wording/branding.

The blocker is not just the words. The build still **connects to external hardware**, receives/displays **BPM**, has **nurse/patient roles**, and supports **patient monitoring**. Apple is reviewing the actual behavior. Under Guideline 1.4.1, health measurement + external hardware is enough for them to ask for regulatory clearance and validation. Under Guideline 3.2, nurse/patient workflows make it look organization/clinic-specific.

**If you refuse to remove features, the realistic paths are:**

1. **Ship through TestFlight**
   Best for a high school/student project demo. You can keep the wearable features and position it as a prototype. This is not public App Store publishing, but it avoids pretending the project is a public medical product.

3. **Public App Store with all features**
   Then you need to answer Apple’s request directly:
   - regulatory clearance for the hardware,
   - hardware test report or peer-reviewed validation,
   - jurisdiction/region statement,
   - functional support URL,
   - demo account and likely review access to hardware or a very clear review setup.

If you only want wording/branding changes, do this, but understand it may not be enough:

**Branding/Wording Changes**
X Remove “PTSD Relief” from the app name if possible. “Relief” implies treatment.
X Replace “medical” with “educational” everywhere.
X Replace “patient” with client.”
X Replace “nurse” with “caretaker.”
X Replace “BPM monitoring” with “sensor demo.”
X Replace “heart rate” with “prototype sensor reading” where you can.
X Replace “Connect Device” with “Connect Prototype Device.”
X Replace “Medical Sources” with “Education Resources.”
X Replace “receiving live heart rate updates” with “receiving prototype sensor updates.”

**App Store Description**
Use something like:

```text
VitalLink Student Wellness is a Coding Minds student project that demonstrates how a mobile app can connect to a prototype companion device and display general wellness-related sensor information.

The app is for educational demonstration and general wellness reflection only. It is not a medical device, does not diagnose, treat, monitor, or prevent any medical condition, and should not be used for emergencies or medical decisions.
```

**Review Notes**
Be blunt:

```text
This app is a Coding Minds student educational project. The companion device is a prototype classroom hardware project, not a commercial medical device. The app does not provide diagnosis, treatment, emergency response, or medical decision support. Sensor readings are shown only as a student prototype demonstration and are not represented as clinically accurate.
```

But the hard truth: Apple may still say, “You connect to external medical hardware and show BPM, so provide 1.4.1 documents.” If you want the best approval chance without feature removal, use **TestFlight or Custom App distribution**, not public App Store.





Apple Notes:

Hello,

Thank you for your efforts to follow our guidelines. There are some outstanding issues that still need your attention.

If you have any questions, we are here to help. Reply to this message in App Store Connect and let us know.

Review Environment

Submission ID: 34592683-389e-4e7f-bea6-da3ea07e9e98
Review Device: iPad Air 11-inch (M3)
Version reviewed: 1.0.2 (5)

Guideline 1.4.1 - Safety - Physical Harm


Issue Description

The app connects to external medical hardware to provide medical services. However, to be compliant with guideline 1.4.1, you must:


- Provide documentation from the appropriate regulatory organization demonstrating regulatory clearance for the medical hardware used by the app.

Next Steps

To resolve this issue, provide the documentation requested above. 

Resources 

Learn more about requirements for medical apps in guideline 1.4.1.
Guideline 1.4.1 - Safety - Physical Harm


Issue Description

The app provides medical related data, health related measurements, diagnoses or treatment advice without the appropriate regulatory clearance. Please note that the app is subject to all of the local regulatory laws where the app is available.

Next Steps

To ensure that the information provided by the app is accurate, please attach your regulatory approval documentation in the App Review Information section of App Store Connect. Once you have posted this documentation, we will continue the review. 

Resources 

Learn more about requirements for medical apps in guideline 1.4.1.
Support

- Reply to this message in your preferred language if you need assistance. If you need additional support, use the Contact Us module.
- Consult with fellow developers and Apple engineers on the Apple Developer Forums.
- Request an App Review Appointment at Meet with Apple to discuss your app's review. Appointments subject to availability during your local business hours on Tuesdays and Thursdays.
- Provide feedback on this message and your review experience by completing a short survey.

Test on the latest betas

Betas of iOS 27, iPadOS 27, macOS 27, tvOS 27 and visionOS 27 are now available. Download the latest betas to prepare your app for upcoming software releases. Learn more about installing and using Apple beta software.
