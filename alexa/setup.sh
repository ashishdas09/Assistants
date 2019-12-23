#!/bin/bash
# https://developer.amazon.com/en-US/docs/alexa/avs-device-sdk/raspberry-pi.html

HOME_PATH="/home/pi"
INSTALL_BASE="$HOME_PATH/Assistants/alexa"
SOURCE_PATH="$INSTALL_BASE/sdk-source"
BUILD_PATH="$INSTALL_BASE/sdk-build"
THIRD_PARTY_PATH="$INSTALL_BASE/third-party"
DB_PATH="$INSTALL_BASE/db"
LOG_FOLDER="${INSTALL_BASE}/log"
APP_NECESSITIES_PATH="$INSTALL_BASE/application-necessities"
SOUNDS_PATH="$APP_NECESSITIES_PATH/sound-files"

PORT_AUDIO_PATH="$THIRD_PARTY_PATH/portaudio"
PORT_AUDIO_FILE="pa_stable_v190600_20161030.tgz";
PORT_AUDIO_DOWNLOAD_URL="http://www.portaudio.com/archives/$PORT_AUDIO_FILE"

AVS_DEVICE_SDK_PATH="${SOURCE_PATH}/avs-device-sdk"
ALEXA_RPI_PATH="${THIRD_PARTY_PATH}/alexa-rpi"

CMAKE_PLATFORM_SPECIFIC=(-DSENSORY_KEY_WORD_DETECTOR=ON \
    -DSENSORY_KEY_WORD_DETECTOR_LIB_PATH=${ALEXA_RPI_PATH}/lib/libsnsr.a \
    -DSENSORY_KEY_WORD_DETECTOR_INCLUDE_DIR=${ALEXA_RPI_PATH}/include \
    -DGSTREAMER_MEDIA_PLAYER=ON \
    -DPORTAUDIO=ON \
    -DPORTAUDIO_LIB_PATH=$PORT_AUDIO_PATH/lib/.libs/libportaudio.a \
    -DPORTAUDIO_INCLUDE_DIR=$PORT_AUDIO_PATH/include)

DEVICE_INFO=="${INSTALL_BASE}/deviceInfo.json"
AVS_DEVICE_SDK_INSTALL_PATH="${AVS_DEVICE_SDK_PATH}/tools/Install"
GEN_CONFIG_FILE_PATH="${AVS_DEVICE_SDK_INSTALL_PATH}/genConfig.sh"
CONFIG_FILE_PATH="${AVS_DEVICE_SDK_INSTALL_PATH}/config.json"
ALEXA_CLIENT_SDK_CONFIG_PATH="${AVS_DEVICE_SDK_PATH}/Integration/AlexaClientSDKConfig.json"

START_SAMPLE_FILE_PATH="${INSTALL_BASE}/startsample.sh"

echo ""
read -r -p "Enter the client id: " CLIENT_ID
echo ""
read -r -p "Enter the product id: " PRODUCT_ID
echo ""

install_dependencies() {
  sudo apt-get update

  sudo apt-get -y install \
  git gcc cmake build-essential libsqlite3-dev libcurl4-openssl-dev libfaad-dev \
  libsoup2.4-dev libgcrypt20-dev libgstreamer-plugins-bad1.0-dev \
  gstreamer1.0-plugins-good libasound2-dev doxygen
  
  sudo apt-get -y install \
  screen sox gedit vim python3-pip
}

build_port_audio() {
  # build port audio
  echo
  echo "==============> BUILDING PORT AUDIO =============="
  echo
  pushd $THIRD_PARTY_PATH
  wget -c $PORT_AUDIO_DOWNLOAD_URL
  tar zxf $PORT_AUDIO_FILE

  pushd portaudio
  ./configure --without-jack
  
  make
  
  popd
  popd
}

clone_avs_device_sdk() {
  
  if [ ! -d "${AVS_DEVICE_SDK_PATH}" ]; then
  {
    pushd $SOURCE_PATH
  
    #get sdk
    echo
    echo "==============> CLONING SDK =============="
    echo
     {
        git clone --single-branch git://github.com/alexa/avs-device-sdk.git
     } || {
        git clone --single-branch https://github.com/shivasiddharth/avs-device-sdk.git
     }
     
    popd
  }
  fi
}

clone_alexa_rpi() {

  if [ -d "${ALEXA_RPI_PATH}" ]; then
  {
    #checkout sensory and build
    echo
    echo "==============> Checkout alexa-rpi =============="
    echo

    pushd $ALEXA_RPI_PATH
    git checkout -- .
    
    popd
  }
  else
  {
    pushd $THIRD_PARTY_PATH

    #get sensory and build
    echo
    echo "==============> CLONING AND BUILDING SENSORY =============="
    echo
     {
        git clone --single-branch git://github.com/Sensory/alexa-rpi.git
     } || {
        git clone --single-branch https://github.com/Sensory/alexa-rpi.git
     }
     
     popd
  }
  fi

  bash "$ALEXA_RPI_PATH/bin/license.sh"
}


get_platform() {
  uname_str=`uname -a`
  result=""

  if [[ "$uname_str" ==  "Linux "* ]] && [[ -f /etc/os-release ]]
  then
    sys_id=`cat /etc/os-release | grep "^ID="`
    if [[ "$sys_id" == "ID=raspbian" ]]
    then
      echo "Raspberry pi"
    fi
  elif [[ "$uname_str" ==  "MINGW64"* ]]
  then
    echo "Windows mingw64"
  fi
}

# The target platform for the build.
PLATFORM=${PLATFORM:-$(get_platform)}

if [[ ! "$CLIENT_ID" =~ amzn1\.application-oa2-client\.[0-9a-z]{32} ]]
then
  echo 'client ID is invalid!'
  exit 1
fi

if [[ ! "$PRODUCT_ID" =~ [0-9a-zA-Z_]+ ]]
then
  echo 'product ID is invalid!'
  echo $PRODUCT_ID
  exit 1
fi

echo "################################################################################"
echo "################################################################################"
echo ""
echo ""
echo "AVS Device SDK $PLATFORM Script - Terms and Agreements"
echo ""
echo ""
echo "The AVS Device SDK is dependent on several third-party libraries, environments, "
echo "and/or other software packages that are installed using this script from "
echo "third-party sources (\"External Dependencies\"). These are terms and conditions "
echo "associated with the External Dependencies "
echo "(available at https://github.com/alexa/avs-device-sdk/wiki/Dependencies) that "
echo "you need to agree to abide by if you choose to install the External Dependencies."
echo ""
echo ""
echo "If you do not agree with every term and condition associated with the External "
echo "Dependencies, enter \"QUIT\" in the command line when prompted by the installer."
echo "Else enter \"AGREE\"."
echo ""
echo ""
echo "################################################################################"
echo "################################################################################"

read input
input=$(echo $input | awk '{print tolower($0)}')
if [ $input == 'quit' ]
then
  exit 1
elif [ $input == 'agree' ]
then
  echo "################################################################################"
  echo "Proceeding with installation"
  echo "################################################################################"
else
  echo "################################################################################"
  echo 'Unknown option'
  echo "################################################################################"
  exit 1
fi

if [ ! -d "$BUILD_PATH" ]
then

  # create / paths
  echo
  echo "==============> CREATING PATHS AND GETTING SOUND FILES ============"
  echo

  mkdir -p $INSTALL_BASE
  mkdir -p $SOURCE_PATH
  mkdir -p $THIRD_PARTY_PATH

  # Make sure required packages are installed
  echo "==============> Install dependencies ============"
  echo
  
  install_dependencies
  
  echo "==============> PortAudio: install and configure PortAudio ============"
  echo
  
  build_port_audio
  
  # commentjson is required to parse comments in AlexaClientSDKConfig.json. Run this command to install commentjson:
  cd $HOME_PATH
  pip install commentjson
  
  echo "==============> Clone the AVS Device SDK ============"
  echo
  clone_avs_device_sdk
  
  echo "==============> Clone the Sensory wake word engine ============"
  echo
  clone_alexa_rpi
  
  # make the SDK
  echo
  echo "==============> BUILDING SDK =============="
  echo
  
  mkdir -p $BUILD_PATH
  
  cd $BUILD_PATH
  cmake ${AVS_DEVICE_SDK_PATH} \
      -DCMAKE_BUILD_TYPE=DEBUG \
      "${CMAKE_PLATFORM_SPECIFIC[@]}"

  cd $BUILD_PATH
  make SampleApp -j2

else
  cd $BUILD_PATH
  make SampleApp -j2
fi

echo
echo "==============> Set up your configuration file =============="
echo

sudo mkdir -p $APP_NECESSITIES_PATH
sudo mkdir -p $SOUNDS_PATH
sudo mkdir -p $DB_PATH
sudo mkdir -p $LOG_FOLDER

cat <<EOF >${CONFIG_FILE_PATH}
{"deviceInfo":{"clientId":"${CLIENT_ID}","productId":"${PRODUCT_ID}"}}
EOF

echo ""
read -r -p "Enter the Device serial number: " DEVICE_SERIAL_NUMBER
echo ""
read -r -p "Enter the Manufacturer name: " MANUFACTURER_NAME
echo ""
read -r -p "Enter the Description: " DEVICE_DESCRIPTION
echo ""

cat <<EOF >${DEVICE_INFO}
{"clientId":"${CLIENT_ID}","productId":"${PRODUCT_ID}","serialNumber":"${DEVICE_SERIAL_NUMBER}","manufacturer":"${MANUFACTURER_NAME}","description":"${DEVICE_DESCRIPTION}"}
EOF

bash ${GEN_CONFIG_FILE_PATH} \
${CONFIG_FILE_PATH} \
${DEVICE_SERIAL_NUMBER} \
${DB_PATH} \
${AVS_DEVICE_SDK_PATH} \
${ALEXA_CLIENT_SDK_CONFIG_PATH} \
-DSDK_CONFIG_MANUFACTURER_NAME="${MANUFACTURER_NAME}" \
-DSDK_CONFIG_DEVICE_DESCRIPTION="${DEVICE_DESCRIPTION}"

echo
echo "==============> SampleApp  =============="
echo

cat <<EOF >${START_SAMPLE_FILE_PATH}
#!/bin/bash

echo
echo "==============> Run and authorize  =============="
echo

PA_ALSA_PLUGHW=1 ${BUILD_PATH}/SampleApp/src/SampleApp ${ALEXA_CLIENT_SDK_CONFIG_PATH}

EOF

sudo chmod +x ${START_SAMPLE_FILE_PATH}

sudo ${START_SAMPLE_FILE_PATH}

echo " **** Completed Configuration/Build ***"
