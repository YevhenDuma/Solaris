#!/bin/bash
### Variables, need to review and change:
temp="/temp"
repopath="/export/repo"
reponame="yevhen"
pkgserver="pkg/server"

#getting version number
#next lines - we get list of all versions, sort them and get last one
echo "Getting virtualbox versions from server ..."
tempfile='/tmp/vbox.temp'
wget -O $tempfile -o /dev/null http://download.virtualbox.org/virtualbox/
version=`cat $tempfile  | awk '{print $2}' | cut -d'=' -f2 | grep -e "[0-9].[0-9]" | grep -v "_" |sed  's#/##g'| sed 's#"##g'| sort --version-sort | tail -1`
allversions=`cat $tempfile  | awk '{print $2}' | cut -d'=' -f2 | grep -e "[0-9].[0-9]" | grep -v "_" |sed  's#/##g'| sed 's#"##g'| sort --version-sort`
#User can choose - download latest version or other one
echo "Latest VirtualBox version - $version. Create IPS package for v.${version}? [Y or ENTER/n]"
read answer
if [ "$answer" != "y" -a "$answer" != "Y" -a x"$answer" != "x" ];
then
	echo "Choose available version:"
	echo $allversions
	read version
fi
#since we know needed version we can build link to download vbox
#getting download link
wget -O $tempfile -o /dev/null http://download.virtualbox.org/virtualbox/${version}
#File should contain work sunos, so we get all files and take only with sunos in the name
filename=`cat $tempfile | awk '{print $2}' | grep -i "Sunos" | cut -d'=' -f2 | grep -e "[0-9].[0-9]" | grep -v "_" |sed  's#/##g'| sed 's#"##g'`
link="http://download.virtualbox.org/virtualbox/${version}/${filename}"
#This will be working directory, where script will download vbox, and create package
tempfolder="VirtualBox-`date +%s`"
mkdir -p ${temp}/${tempfolder}
echo "Downloading VirtualBox ... "
wget -o /dev/null -O ${temp}/${tempfolder}/${filename} $link
cd ${temp}/${tempfolder}
#untar downloaded file
pkgfile=`tar -zxvf $filename | grep ".pkg"`
echo "Uncompressing $filename ..."
mkdir ips
#this will transform/unpack pkg file 
pkgtrans $pkgfile ${temp}/${tempfolder}/ips/ all
cd ips
#pkg contain postinstall script, but philosophy of ips - no more postinstall scripts that cause problems, so we need to delete them before create ips
deletefiles=`ls SUNWvbox/install`
for deletefile in $deletefiles
do
sed "/${deletefile}/d" SUNWvbox/pkgmap > SUNWvbox/pkgmap.tmp
mv SUNWvbox/pkgmap.tmp SUNWvbox/pkgmap
done
rm -rf SUNWvbox/install
#here will be part for postinstall script
mkdir -p ${temp}/${tempfolder}/ips/SUNWvbox/smf/
#variables for paths
smffile="${temp}/${tempfolder}/ips/SUNWvbox/smf/virtualbox.xml"
#manually, just echo data info xml file
echo "<?xml version=\"1.0\"?> " > $smffile
echo "<!DOCTYPE service_bundle SYSTEM \"/usr/share/lib/xml/dtd/service_bundle.dtd.1\">">> $smffile
echo "<service_bundle type='manifest' name='VirtualBox:run-once'>">> $smffile
echo "<service">> $smffile
echo " name='system/virtualbox/run-once'">> $smffile
echo " type='service'">> $smffile
echo " version='1'>">> $smffile
echo "<single_instance />">> $smffile
echo "<dependency">> $smffile
echo " name='fs-local'">> $smffile
echo " grouping='require_all'">> $smffile
echo " restart_on='none'">> $smffile
echo " type='service'>">> $smffile
echo "<service_fmri value='svc:/system/filesystem/local:default' />">> $smffile
echo "</dependency>">> $smffile
echo "<dependent">> $smffile
echo " name='myapplication_self-assembly-complete'">> $smffile
echo " grouping='optional_all'">> $smffile
echo " restart_on='none'>">> $smffile
echo "<service_fmri value='svc:/milestone/self-assembly-complete' />">> $smffile
echo "</dependent>">> $smffile
echo "<instance enabled='true' name='default'>">> $smffile
echo "<exec_method">> $smffile
echo " type='method'">> $smffile
echo " name='start'">> $smffile
echo " exec='/opt/VirtualBox/ipsinstall.sh --ips'">> $smffile
echo " timeout_seconds='0'/>">> $smffile
echo "<exec_method">> $smffile
echo " type='method'">> $smffile
echo " name='stop'">> $smffile
echo " exec=':true'">> $smffile
echo " timeout_seconds='0'/>">> $smffile
echo "<property_group name='startd' type='framework'>">> $smffile
echo "<propval name='duration' type='astring' value='transient' />">> $smffile
echo "</property_group>">> $smffile
echo "<property_group name='config' type='application'>">> $smffile
echo "<propval name='assembled' type='boolean' value='false' />">> $smffile
echo "</property_group>">> $smffile
echo "</instance>">> $smffile
echo "</service>">> $smffile
echo "</service_bundle>">> $smffile

echo "Generating ips package ..."
#next lines will create p5m file and publish into repository
echo "set name=pkg.fmri value=pkg://${reponame}/service/virtualbox@${version},5.11-1.0" > ./SUNWvbox/virtualbox.p5m
pkgsend generate ./SUNWvbox | pkgfmt >> ./SUNWvbox/virtualbox.p5m
echo "file smf/virtualbox.xml path=var/svc/manifest/system/virtualbox.xml owner=root group=root mode=644 restart_fmri=svc:/system/manifest-import:default" >> ./SUNWvbox/virtualbox.p5m
#publish
pkgsend publish -d ./SUNWvbox -s $repopath ./SUNWvbox/virtualbox.p5m
#End of vbox package generation

# Generationg VirtualBox Extension Pack
#next lines will download same ext file as version of virtualbox
echo "Downloading VirtualBox Extension Pack ..."
vboxpath="root/opt/VirtualBox"
mkdir -p VBoxExt/${vboxpath}
mkdir -p VBoxExt/smf
wget -O $tempfile -o /dev/null http://download.virtualbox.org/virtualbox/${version}
filename=`cat $tempfile | awk '{print $2}' | grep -i "vbox-extpack" | cut -d'=' -f2 | grep -e "[0-9].[0-9]" | tail -1 | sed  's#/##g'| sed 's#"##g'`
link="http://download.virtualbox.org/virtualbox/${version}/${filename}"
rm $tempfile
wget -o /dev/null -O ${temp}/${tempfolder}/ips/VBoxExt/${vboxpath}/${filename} $link
#variables for paths
smffile="${temp}/${tempfolder}/ips/VBoxExt/smf/virtualbox-ext.xml"
p5mfile="${temp}/${tempfolder}/ips/VBoxExt/virtualbox-ext.p5m"
echo "Preparing files to packege virtualbox-ext... "
#creating smf
#manually, just echo data info xml file
echo "<?xml version=\"1.0\"?> " > $smffile
echo "<!DOCTYPE service_bundle SYSTEM \"/usr/share/lib/xml/dtd/service_bundle.dtd.1\">">> $smffile
echo "<service_bundle type='manifest' name='VirtualBox-Extension:run-once'>">> $smffile
echo "<service">> $smffile
echo " name='system/virtualbox-ext/run-once'">> $smffile
echo " type='service'">> $smffile
echo " version='1'>">> $smffile
echo "<single_instance />">> $smffile
echo "<dependency">> $smffile
echo " name='fs-local'">> $smffile
echo " grouping='require_all'">> $smffile
echo " restart_on='none'">> $smffile
echo " type='service'>">> $smffile
echo "<service_fmri value='svc:/system/filesystem/local:default' />">> $smffile
echo "</dependency>">> $smffile
echo "<dependent">> $smffile
echo " name='myapplication_self-assembly-complete'">> $smffile
echo " grouping='optional_all'">> $smffile
echo " restart_on='none'>">> $smffile
echo "<service_fmri value='svc:/milestone/self-assembly-complete' />">> $smffile
echo "</dependent>">> $smffile
echo "<instance enabled='true' name='default'>">> $smffile
echo "<exec_method">> $smffile
echo " type='method'">> $smffile
echo " name='start'">> $smffile
echo " exec='/opt/VirtualBox/VBoxManage extpack install /opt/VirtualBox/${filename}'">> $smffile
echo " timeout_seconds='0'/>">> $smffile
echo "<exec_method">> $smffile
echo " type='method'">> $smffile
echo " name='stop'">> $smffile
echo " exec=':true'">> $smffile
echo " timeout_seconds='0'/>">> $smffile
echo "<property_group name='startd' type='framework'>">> $smffile
echo "<propval name='duration' type='astring' value='transient' />">> $smffile
echo "</property_group>">> $smffile
echo "<property_group name='config' type='application'>">> $smffile
echo "<propval name='assembled' type='boolean' value='false' />">> $smffile
echo "</property_group>">> $smffile
echo "</instance>">> $smffile
echo "</service>">> $smffile
echo "</service_bundle>">> $smffile

### Creating p5m
echo "set name=pkg.fmri value=pkg://${reponame}/service/virtualbox-ext@${version},5.11-1.0" > $p5mfile
echo "set name=pkg.summary value=\"Oracle VM VirtualBox\" ">> $p5mfile
echo "set name=pkg.description value=\"A powerful PC virtualization solution\" ">> $p5mfile
echo "set name=pkg.send.convert.email value=info@virtualbox.org" >> $p5mfile
echo "dir  path=opt/VirtualBox owner=root group=bin mode=0755" >> $p5mfile
echo "file root/opt/VirtualBox/${filename} path=opt/VirtualBox/${filename} owner=root group=bin mode=0755" >> $p5mfile
echo "file smf/virtualbox-ext.xml path=var/svc/manifest/system/virtualbox-ext.xml owner=root group=root mode=644 restart_fmri=svc:/system/manifest-import:default" >> $p5mfile
echo "depend type=require fmri=pkg://${reponame}/service/virtualbox@${version},5.11-1.0" >> $p5mfile

### Genetating vbox-ext package
echo "Genetating ips package ..."
pkgsend publish -d ./VBoxExt -s $repopath ./VBoxExt/virtualbox-ext.p5m

pkgrepo refresh -s  $repopath
svcadm restart $pkgserver
echo "IPS package created and published. $pkgserver restarted."
rm -rf ${temp}/${tempfolder} > /dev/null 2>&1
rmdir ${temp}/${tempfolder}/ips > /dev/null 2>&1
rm -rf ${temp}/${tempfolder} > /dev/null 2>&1
