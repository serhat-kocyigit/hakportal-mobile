$sourceDir = "C:\Users\lenovo\.gemini\antigravity\brain\99577036-8959-4944-a673-6acc12fe43d3"
$targetDir = "c:\Users\lenovo\Desktop\hakportal_mobile\assets\icon"

New-Item -ItemType Directory -Force -Path $targetDir
Copy-Item "$sourceDir\hakportal_logo_1773824897741.png" -Destination "$targetDir\app_icon.png" -Force
