// Written by FreeBSD-setup: the LunaBSD wallpaper for each desktop that
// still shows Plasma's own default. Plasma runs this once per user; a
// wallpaper someone picked is never replaced.
// the package, so Plasma picks the day or night picture by colour scheme
var image = "file:///usr/local/share/wallpapers/LunaBSD/";
var all = desktops();
for (var i = 0; i < all.length; i++) {
	var d = all[i];
	d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
	var cur = d.readConfig("Image", "");
	if (d.wallpaperPlugin == "org.kde.image" && (cur == "" || cur.indexOf("Next") >= 0)) {
		d.writeConfig("Image", image);
	}
}
