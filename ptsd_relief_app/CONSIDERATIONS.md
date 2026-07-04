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