# ---------------------------------------------------------------------------
#  IReader -- lector y biblioteca para iPad mini 1 (iOS 9, armv7).
#
#  Interfaz 100% en codigo: sin storyboards, sin XIB, sin Swift.
#  Prioridad: mostrar cada documento tal cual es (fuentes, margenes y tamano
#  de pagina originales), guardando siempre la pagina donde se dejo.
#
#  Compilar:  make clean && make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
# ---------------------------------------------------------------------------

TARGET = iphone:clang:9.3:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IReader

IReader_FILES = \
	main.m \
	AppDelegate.m \
	IRTheme.m \
	IRSettings.m \
	IRIcons.m \
	IRUtils.m \
	IRModels.m \
	IRLibrary.m \
	IRDialog.m \
	IRMetadata.m \
	IRImportManager.m \
	IRFileBrowserViewController.m \
	IRLibraryViewController.m \
	IRBookCell.m \
	IRBookDetailViewController.m \
	IRRootViewController.m \
	IRSettingsViewController.m \
	IRReaderContainerViewController.m \
	IRArchive.m \
	IRPDFPageView.m \
	IRPDFOutline.m \
	IRPDFThumbnails.m \
	IRPDFReaderViewController.m \
	IRTextPaginator.m \
	IRMarkdown.m \
	IRTextReaderViewController.m \
	IRImageReaderViewController.m \
	IRComicReaderViewController.m \
	IRWebReaderViewController.m \
	IREPUBDocument.m \
	IRHexReaderViewController.m \
	IRHTTPServer.m \
	IRWiFiViewController.m

# Frameworks de iOS 9. ImageIO para miniaturas, CoreText para paginar texto,
# CoreImage para el codigo QR del servidor Wi-Fi, AVFoundation para multimedia.
IReader_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore CoreText \
	CoreImage ImageIO MobileCoreServices AVFoundation CoreMedia CoreVideo \
	MediaPlayer CFNetwork Security

# Theos compila con -Werror: silenciamos solo avisos menores.
IReader_CFLAGS = -fobjc-arc \
	-Wno-deprecated-declarations \
	-Wno-unused-parameter \
	-Wno-unused-variable \
	-Wno-unused-function \
	-Wno-objc-method-access \
	-Wno-format \
	-Wno-shorten-64-to-32 \
	-Wno-unknown-warning-option

IReader_RESOURCE_DIRS = Resources

# libz: lectura y escritura de ZIP (EPUB, CBZ, Office).
IReader_LDFLAGS = -Wl,-dead_strip -lz

# Permisos de jailbreak: lectura amplia del sistema de ficheros.
IReader_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
