// Written by FreeBSD-setup: the LunaBSD wallpaper for each desktop that
// still shows Plasma's own default. Plasma runs this once per user; a
// wallpaper someone picked is never replaced.
var image = "file:///usr/local/share/wallpapers/LunaBSD/contents/images/3840x2160.jpg";
var all = desktops();
for (var i = 0; i < all.length; i++) {
	var d = all[i];
	d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
	var cur = d.readConfig("Image", "");
	if (d.wallpaperPlugin == "org.kde.image" && (cur == "" || cur.indexOf("Next") >= 0)) {
		d.writeConfig("Image", image);
	}
}
