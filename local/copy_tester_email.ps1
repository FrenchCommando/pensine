# Puts the Pensine tester-recruitment email on the Windows clipboard as rich HTML.
# Paste into Gmail compose with Ctrl+V - link text is clickable, URLs stay hidden.

Add-Type -AssemblyName System.Windows.Forms

$bodyHtml = @'
<p>Hi,</p>
<p>I''m looking for Android testers for Pensine, a little notes app I''ve been building - lofi, visual, all local. Free, open source.</p>
<p>Live <a href="https://frenchcommando.github.io/pensine/">on the web</a> and on the <a href="https://apps.apple.com/app/pensine/id6762313502">App Store</a>. Android is stuck in Google Play''s closed-test track until I have 12 testers for 14 days.</p>
<p>Three clicks, Google account only:</p>
<ol>
<li><a href="https://groups.google.com/g/pensine-testers">Join the testers group</a></li>
<li><a href="https://play.google.com/apps/testing/com.frenchcommando.pensine">Accept the tester invite</a></li>
<li><a href="https://play.google.com/store/apps/details?id=com.frenchcommando.pensine">Install from Play Store</a></li>
</ol>
<p>Same Google account for all three. Uninstall anytime.</p>
'@

$prefix = "<html><body>`r`n<!--StartFragment-->"
$suffix = "<!--EndFragment-->`r`n</body></html>"
$headerTemplate = "Version:0.9`r`nStartHTML:{0:0000000000}`r`nEndHTML:{1:0000000000}`r`nStartFragment:{2:0000000000}`r`nEndFragment:{3:0000000000}`r`n"
$placeholder = $headerTemplate -f 0,0,0,0

$utf8 = [System.Text.Encoding]::UTF8
$startHtml = $utf8.GetByteCount($placeholder)
$startFragment = $startHtml + $utf8.GetByteCount($prefix)
$endFragment = $startFragment + $utf8.GetByteCount($bodyHtml)
$endHtml = $endFragment + $utf8.GetByteCount($suffix)

$finalHeader = $headerTemplate -f $startHtml, $endHtml, $startFragment, $endFragment
$cfHtml = $finalHeader + $prefix + $bodyHtml + $suffix

$plainFallback = @'
Hi,

I''m looking for Android testers for Pensine, a little notes app I''ve been building - lofi, visual, all local. Free, open source.

Live on the web (https://frenchcommando.github.io/pensine/) and on the App Store (https://apps.apple.com/app/pensine/id6762313502). Android is stuck in Google Play''s closed-test track until I have 12 testers for 14 days.

Three clicks, Google account only:

1. Join the testers group: https://groups.google.com/g/pensine-testers
2. Accept the tester invite: https://play.google.com/apps/testing/com.frenchcommando.pensine
3. Install from Play Store: https://play.google.com/store/apps/details?id=com.frenchcommando.pensine

Same Google account for all three. Uninstall anytime.

Thanks!
Martin
'@

$do = New-Object System.Windows.Forms.DataObject
$do.SetData([System.Windows.Forms.DataFormats]::Html, $cfHtml)
$do.SetData([System.Windows.Forms.DataFormats]::UnicodeText, $plainFallback)
[System.Windows.Forms.Clipboard]::SetDataObject($do, $true)

Write-Host ""
Write-Host "  DONE. Email on clipboard." -ForegroundColor Green
Write-Host "  Open Gmail, press Ctrl+V, send."
Write-Host ""
