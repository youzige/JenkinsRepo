#!bin/bash
#Use:命令行进入目录直接执行sh Build+DeployToFir.sh即可完成打包发布到fir.im

export LC_ALL=zh_CN.GB2312;
export LANG=zh_CN.GB2312

###############设置需编译的项目配置名称
buildConfig=$1 #编译的方式,有Release,Debug，Intranet,Official,Extranet,自定义的AdHoc等

if [ -z $buildConfig ]; then
buildConfig="Release"
fi

echo "~~~~~~~~~~~~~~~~~~~当前配置环境是$buildConfig~~~~~~~~~~~~~~~~~~~"

##########################################################################################
##############################以下部分为自动生产部分，不需要手动修改############################
##########################################################################################
projectName=`find . -name *.xcodeproj | awk -F "[/.]" '{print $(NF-1)}'` #项目名称
#projectName="PokerClub"
projectDir=`pwd` #项目所在目录的绝对路径
wwwIPADir=./output #ipa，icon最后所在的目录绝对路径
isWorkSpace=true  #判断是用的workspace还是直接project，workspace设置为true，否则设置为false

echo "~~~~~~~~~~~~~~~~~~~开始编译~~~~~~~~~~~~~~~~~~~"
if [ -d "$wwwIPADir" ]; then
rm -d -f -r $wwwIPADir
else
mkdir -pv $wwwIPADir
echo "创建${wwwIPADir}目录成功"
fi

###############进入项目目录
cd $projectDir
rm -rf ./build
buildAppToDir=$projectDir/build #编译打包完成后.app文件存放的目录

###############获取版本号,bundleID
infoPlist="$projectName/Info.plist"
bundleVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $infoPlist`
bundleIdentifier=`/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" $infoPlist`
bundleBuildVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $infoPlist`

###############开始编译app
if $isWorkSpace ; then  #判断编译方式
echo  "开始编译workspace...."
xcodebuild archive -workspace $projectName.xcworkspace -scheme $projectName -configuration $buildConfig -archivePath $buildAppToDir
else
echo  "开始编译target...."
xcodebuild  -target  $projectName  -configuration $buildConfig clean build SYMROOT=$buildAppToDir
fi
#判断编译结果
if test $? -eq 0; then
echo "~~~~~~~~~~~~~~~~~~~编译成功~~~~~~~~~~~~~~~~~~~"
else
echo "~~~~~~~~~~~~~~~~~~~编译失败~~~~~~~~~~~~~~~~~~~"
exit 1
fi

###############开始打包成.ipa
ipaName=`echo $projectName | tr "[:upper:]" "[:lower:]"` #将项目名转小写
echo "开始打包$projectName.app成$projectName.ipa....."
xcodebuild -exportArchive -archivePath $projectDir/build.xcarchive -exportOptionsPlist $projectDir/ExportOptions.plist -exportPath $wwwIPADir -allowProvisioningUpdates

###############开始拷贝到目标下载目录
#检查文件是否存在
if [ -f "$wwwIPADir/$ipaName.ipa" ]; then
echo "打包$ipaName.ipa成功."
else
echo "打包$ipaName.ipa失败."
exit 1
fi

#拷贝ipa文件, 如果有文件名参数则使用参数文件名，否则按默认规则构造文件名
fileNameParam=$2
if [ ! "$fileNameParam" ]; then
path=$wwwIPADir/$projectName$(date +%Y%m%d%H%M%S).ipa
else
path=$wwwIPADir/${fileNameParam}
fi
cp -f -p $wwwIPADir/$ipaName.ipa $path
#rm -rf $projectDir/build.xcarchive
mv $projectDir/build.xcarchive $wwwIPADir #保存archive文件，方便定位bug位置
rm -rf $wwwIPADir/$ipaName.ipa
echo "~~~~~~~~~~~~~~~~~~~结束编译，处理成功~~~~~~~~~~~~~~~~~~~"

#文件名为空，则开启上传(jenkins调用该脚本会传入文件名参数，不开启上传)
#if [ ! "$fileNameParam" ]; then
#export LANG=en_US
#export LC_ALL=en_US;
#echo "正在上传到fir.im...."
#fir p $path
#echo "\n打包上传更新成功！"
#open $wwwIPADir
#fi
