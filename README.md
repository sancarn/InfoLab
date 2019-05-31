# InfoLite-Lab

An Open Source InfoWorks/InfoNet tool for executing Ruby scripts!

## Description

InfoLite Lab adds a tool window to InfoWorks/InfoNet which allows you to execute and run ruby scripts instantly

Simply double click on a ruby script to execute it! You can also search in the database of ruby scripts in the search bar for scripts you need.

The scripts and icons can be found in `./scripts/`. If you want to add scripts to the collection, just drop them into this folder. You can also optionally include a png file which will act as it's icon. Ensure this file has the same name as the ruby script but with the `.rb.png` extension:

```
scripts/myScript.rb      <-- Script
scripts/myScript.rb.png  <-- Image
```

If you do not supply an image, a default image will be used instead. Click refresh if your new script doesn’t display immediately.

You can also run multiple ruby scripts sequentially. Select multiple scripts and press enter, you will be prompted by a message asking:

> You have selected more than one script. Would you like to execute them all sequentially?

Click yes to run both scripts sequentially.

## InfoLite-Lab Beta demo

[![Video demo of executing scripts](https://img.youtube.com/vi/kxfqf5nJXig/0.jpg)](https://www.youtube.com/watch?v=kxfqf5nJXig)

## License

The code in this repository is released under GPL software license as an attempt to force openness of derivative work.
