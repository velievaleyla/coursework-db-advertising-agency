@echo off
chcp 65001 > nul
echo ========================================================
echo   Синхронізація курсової роботи з GitHub (velievaleyla)
echo ========================================================
echo.

git status
echo.
set /p confirm="Бажаєте надіслати зміни на GitHub? (y/n): "
if /i "%confirm%" neq "y" goto end

git add .
set /p msg="Введіть коментар до комміту (Enter для стандартного): "
if "%msg%"=="" set msg=Update coursework database materials
git commit -m "%msg%"
git push origin master

echo.
echo ========================================================
echo   Успішно оновлено: https://github.com/velievaleyla/coursework-db-advertising-agency
echo ========================================================
:end
pause
