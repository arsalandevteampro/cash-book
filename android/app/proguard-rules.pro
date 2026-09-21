# Meta Audience Network Proguard/R8 Keep Rules
-dontwarn com.facebook.ads.**
-dontwarn com.facebook.infer.annotation.**
-keep class com.facebook.ads.** { *; }
-keepclassmembers class com.facebook.ads.** { *; }

# Meta AdMob Mediation Adapter Keep Rules
-keep class com.google.ads.mediation.facebook.** { *; }
-dontwarn com.google.ads.mediation.facebook.**
