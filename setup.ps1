
$venvDir = ".venv"
$activateScript = "$venvDir\Scripts\Activate.ps1"
$requirementsFile = "requirements.txt"

if (-not (Test-Path $venvDir)) {
	Write-Host "Creating virtual environment...`n"
	python -m venv $venvDir
}

Write-Host "Activating virtual environment...`n"
& $activateScript

if (-not (Test-Path $requirementsFile)) {
	Write-Error "requirements.txt not found!"
	return
}

function Convert-Version ($versionString) {
	[version]$versionString
}

$currentPipVersionString = ((pip --version) | Select-Object -First 1) -replace '^pip ([\d\.]+).*','$1'
$currentPipVersion = Convert-Version $currentPipVersionString

$pypiResponse = Invoke-RestMethod -Uri "https://pypi.org/pypi/pip/json" -UseBasicParsing
$latestPipVersionString = $pypiResponse.info.version
$latestPipVersion = Convert-Version $latestPipVersionString

Write-Host "Pip Status"
Write-Host "-------------------------------------------"
Write-Host "Current: $currentPipVersionString"
Write-Host "Latest: $latestPipVersionString"

if ($currentPipVersion -lt $latestPipVersion) {
	Write-Host "Upgrading pip...`n"
	python -m pip install --upgrade pip
} else {
	Write-Host "OK`n"
}

$requiredPackages = @{}
Get-Content $requirementsFile | ForEach-Object {
	$_ = $_.Trim()
	if (-not $_ -or $_ -like '#*') { return }
	if ($_ -match '^([^=]+)==(.+)$') {
		$name = $matches[1].ToLower()
		$version = $matches[2]
		$requiredPackages[$name] = $version
	}
}

$installedPackages = @{}
pip list --format=freeze | ForEach-Object {
	if ($_ -match '^([^=]+)==(.+)$') {
		$name = $matches[1].ToLower()
		$version = $matches[2]
		$installedPackages[$name] = $version
	}
}

Write-Host "Checking Dependencies"
Write-Host "-------------------------------------------"

foreach ($pkg in $requiredPackages.Keys) {
	$requiredVersion = $requiredPackages[$pkg]
	if (-not $installedPackages.ContainsKey($pkg) -or $installedPackages[$pkg] -ne $requiredVersion) {
		Write-Host "Installing $pkg==$requiredVersion ..."
		pip install "$pkg==$requiredVersion"
		Write-Host "-------------------------------------------`n"
	} else {
		Write-Host "$pkg==$requiredVersion : OK"
	}
}

Write-Host "`nStarting Project Setup"
Write-Host "-------------------------------------------"

if (-not (Test-Path "manage.py")) {
	Write-Host "Creating Django project...`n"
	django-admin startproject base .
} else {
	Write-Host "Project Setup OK...`n"
	pip freeze > requirements.txt
}

Write-Host "`nStarting Folder Setup"
Write-Host "-------------------------------------------"

$foldersToCreate = @(
	"base/settings"
    "apps",
    "apps/utils",
    "static",
    "media"
)

$includeOptional = Read-Host "Do you want to include optional template folders? (y)"

if ($includeOptional -match "^[Yy]") {
    $optionalFolders = @(
        "templates",
        "templates/base",
        "templates/base/partials",
        "templates/base/components"
    )
    $foldersToCreate += $optionalFolders
}

foreach ($folder in $foldersToCreate) {
    if (-not (Test-Path $folder)) {
        Write-Host "Creating folder: $folder"
        New-Item -ItemType Directory -Path $folder | Out-Null
    } else {
        Write-Host "Folder already exists: $folder"
    }
}

Write-Host "`nStarting File Setup"
Write-Host "-------------------------------------------"


$baseSettings = @'
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "django_extensions",
    "django_filters",
    "drf_yasg",
    "rest_framework",
    "rest_framework.authtoken",
    "apps.utils",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "base.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "base.wsgi.application"
'@

$stagingSettings = @"
from .configuration import *

import os

ALLOWED_HOSTS = []

CORS_ALLOWED_ORIGINS = []

CORS_ALLOW_ALL_ORIGINS = False

CORS_ALLOW_HEADERS = [
    "content-type",
    "authorization",
]

CORS_ALLOW_METHODS = [
    "GET",
    "POST",
    "PUT",
    "PATCH",
    "DELETE",
    "OPTIONS",
]

DATABASES = {
    "default": {
        "ENGINE": str(os.getenv("DB_ENGINE")),
        "NAME": str(os.getenv("DB_NAME")),
        "USER": str(os.getenv("DB_USER")),
        "PASSWORD": str(os.getenv("DB_PASS")),
        "HOST": str(os.getenv("DB_HOST")),
        "PORT": int(os.getenv("DB_PORT")),
    }
}


EMAIL_BACKEND = os.getenv(
    "EMAIL_BACKEND", "django.core.mail.backends.smtp.EmailBackend"
)

EMAIL_HOST = str(os.getenv("EMAIL_HOST", ""))

EMAIL_PORT = int(os.getenv("EMAIL_PORT", 587))

EMAIL_USE_TLS = bool(os.getenv("EMAIL_USE_TLS"))

EMAIL_USE_SSL = bool(os.getenv("EMAIL_USE_SSL"))

EMAIL_HOST_USER = str(os.getenv("EMAIL_HOST_USER"))

EMAIL_HOST_PASSWORD = str(os.getenv("EMAIL_HOST_PASSWORD"))

DEFAULT_FROM_EMAIL = EMAIL_HOST_USER
"@

$productionSettings = @'
from .configuration import *

import os

ALLOWED_HOSTS = []

CORS_ALLOWED_ORIGINS = []

CORS_ALLOW_ALL_ORIGINS = False

CORS_ALLOW_HEADERS = [
    "content-type",
    "authorization",
]

CORS_ALLOW_METHODS = [
    "GET",
    "POST",
    "PUT",
    "PATCH",
    "DELETE",
    "OPTIONS",
]

DATABASES = {
    "default": {
        "ENGINE": str(os.getenv("DB_ENGINE")),
        "NAME": str(os.getenv("DB_NAME")),
        "USER": str(os.getenv("DB_USER")),
        "PASSWORD": str(os.getenv("DB_PASS")),
        "HOST": str(os.getenv("DB_HOST")),
        "PORT": int(os.getenv("DB_PORT")),
    }
}


EMAIL_BACKEND = os.getenv(
    "EMAIL_BACKEND", "django.core.mail.backends.smtp.EmailBackend"
)

EMAIL_HOST = str(os.getenv("EMAIL_HOST", ""))

EMAIL_PORT = int(os.getenv("EMAIL_PORT", 587))

EMAIL_USE_TLS = bool(os.getenv("EMAIL_USE_TLS"))

EMAIL_USE_SSL = bool(os.getenv("EMAIL_USE_SSL"))

EMAIL_HOST_USER = str(os.getenv("EMAIL_HOST_USER"))

EMAIL_HOST_PASSWORD = str(os.getenv("EMAIL_HOST_PASSWORD"))

DEFAULT_FROM_EMAIL = EMAIL_HOST_USER
'@


$authenticationSettings = @'
AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]
'@

$configurationSettings = @'
from .authentication import *
from .base import *

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LANGUAGE_CODE = "en-IN"

MEDIA_ROOT = BASE_DIR / "media"

MEDIA_URL = "/media/"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
    ],
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
    "DEFAULT_SCHEMA_CLASS": "rest_framework.schemas.coreapi.AutoSchema",
    "DEFAULT_VERSIONING_CLASS": "rest_framework.versioning.AcceptHeaderVersioning",
    "DEFAULT_VERSION": "1.0",
    "ALLOWED_VERSIONS": ["1.0"],
    "VERSION_PARAM": "version",
}

SESSION_COOKIE_AGE = 7200

SESSION_ENGINE = "django.contrib.sessions.backends.db"

SESSION_EXPIRE_AT_BROWSER_CLOSE = True

SESSION_SERIALIZER = "django.contrib.sessions.serializers.JSONSerializer"

STATIC_URL = "/static/"

STATIC_ROOT = BASE_DIR / "static"

SWAGGER_SETTINGS = {
    "SECURITY_DEFINITIONS": {
        "Token": {
            "type": "apiKey",
            "name": "Authorization",
            "in": "header",
            "description": "Enter the token in the format: Token abc12345def67890ghijklm",
        }
    },
    "USE_SESSION_AUTH": False,
}

TIME_ZONE = "Asia/Kolkata"

USE_I18N = True

USE_TZ = True
'@

$developmentSettings = @'
from .configuration import *

ALLOWED_HOSTS = ["*"]

ALLOWED_IPS = ["127.0.0.1"]

CORS_ALLOW_ALL_ORIGINS = True

CORS_ALLOW_HEADERS = [
    "content-type",
    "authorization",
]

CORS_ALLOW_METHODS = [
    "GET",
    "POST",
    "PUT",
    "PATCH",
    "DELETE",
    "OPTIONS",
]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

DEFAULT_FROM_EMAIL = "test@fdms.com"

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

SECRET_KEY = "django-insecure-)!+fomb@+ir(1m&(5x(7$*h1%6f8%#3_ele6uhhgyn3^jd&rnu"
'@

$utilsApp = @'
from django.apps import AppConfig

class UtilsConfig(AppConfig):
    name = "apps.utils"

    class Meta:
        verbose_name = "Util"
        verbose_name_plural = "Utils"
'@

$baseAsgiContent = @"
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "base.settings")

application = get_asgi_application()
"@

$baseWsgiContent = @"
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "base.settings")

application = get_wsgi_application()
"@

$baseUrlsContent = @"
from django.conf import settings
from django.conf.urls.static import static

from django.contrib import admin
from django.urls import path

from base.views import index

urlpatterns = [
    path("", index, name="index"),
    path("admin/", admin.site.urls),
]

urlpatterns += static(settings.MEDIA_URL, documnent_root=settings.MEDIA_ROOT)
"@

$gitignoreContent = @'
.venv
static
media
__pycache__
*.pyc
'@

$managePyContent = @"
import os
import sys


def main():
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "base.settings")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError("Couldn't import Django.") from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
"@

$editorConfigContent = @"
root = true

[*]
indent_style = tab
indent_size = 4
end_of_line = crlf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = false
"@

$indexContent = @"
{% extends 'base/base.html' %}

{% block title %}
Site
{% endblock title %}

{% block content %}
<p>Hello.</p>
{% endblock content %}
"@

$baseContent = @"
<!DOCTYPE html>
<html lang="en">

<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>{% block title %}

		{% endblock title %}
	</title>

	{% block styles %}

	{% endblock styles %}
</head>

<body>
	{% block content %}

	{% endblock content %}
</body>

</html>
"@

$footerContent = @"
<footer>
	<p>Akash Damle, 2025.</p>
</footer>
"@

$navbarContent = @"
<nav>
	<p>Site</p>
	<ul>
		<li>Login</li>
		<li>Logout</li>
	</ul>
</nav>
"@

$messagesContent = @"
{% if messages %}
	{% for message in messages %}
		<p>{{message}}</p>
	{% endfor %}

{% endif %}
"@

$managePath = "manage.py"
$asgiPath = "base/asgi.py"
$wsgiPath = "base/wsgi.py"
$uniqueMarker = 'os.environ.setdefault("DJANGO_SETTINGS_MODULE", "base.settings")'

if (Test-Path $managePath) {
    $currentContent = Get-Content $managePath -Raw
} else {
    $currentContent = ""
}

if (-not $currentContent.Contains($uniqueMarker)) {
    Write-Host "Updating manage.py..."
    $managePyContent | Set-Content -Path $managePath -Encoding UTF8 -Force
    Write-Host "manage.py updated successfully."
} else {
    Write-Host "manage.py already configured. Skipping update."
}

if (Test-Path $asgiPath) {
    $currentContent = Get-Content $asgiPath -Raw
} else {
    $currentContent = ""
}

if (-not $currentContent.Contains($uniqueMarker)) {
    Write-Host "Updating asgi.py..."
    $baseAsgiContent | Set-Content -Path $asgiPath -Encoding UTF8 -Force
    Write-Host "asgi.py updated successfully."
} else {
    Write-Host "asgi.py already configured. Skipping update."
}

if (Test-Path $wsgiPath) {
    $currentContent = Get-Content $wsgiPath -Raw
} else {
    $currentContent = ""
}

if (-not $currentContent.Contains($uniqueMarker)) {
    Write-Host "Updating wsgi.py..."
    $baseWsgiContent | Set-Content -Path $wsgiPath -Encoding UTF8 -Force
    Write-Host "wsgi.py updated successfully."
} else {
    Write-Host "wsgi.py already configured. Skipping update."
}

if ($includeOptional -match "^[Yy]") {
    $baseViewsContent = @"
from django.shortcuts import render

def index(request):
    return render(request, "index.html")
"@
} else {
    $baseViewsContent = @"
from django.http import JsonResponse

def index(request):
    return JsonResponse("Hi", safe=False)
"@
}


$filesToCreate = @{
	".editorconfig" = $editorConfigContent
    ".gitignore" = $gitignoreContent
    "base/views.py" = $baseViewsContent
    "base/urls.py" = $baseUrlsContent
    "base/settings/__init__.py" = "from .development import *  # noqa"
    "base/settings/base.py" = $baseSettings
    "base/settings/authentication.py" = $authenticationSettings
    "base/settings/configuration.py" = $configurationSettings
    "base/settings/development.py" = $developmentSettings
    "base/settings/staging.py" = $stagingSettings
    "base/settings/production.py" = $productionSettings
    "apps/__init__.py" = ""
    "apps/utils/__init__.py" = ""
    "apps/utils/apps.py" = $utilsApp
    "apps/utils/helpers.py" = ""
}

$optionalFilesWithContent = @{
	"templates/index.html" = $indexContent
    "templates/base/index.html" = $baseContent
    "templates/base/components/navbar.html" = $navbarContent
    "templates/base/components/footer.html" = $footerContent
    "templates/base/partials/messages.html" = $messagesContent
}


$includeOptionalFiles = Read-Host "Do you want to include optional templates? (y/n)"

if ($includeOptionalFiles -match "^[Yy]") {
    foreach ($file in $optionalFilesWithContent.Keys) {
        if (-not $filesToCreate.ContainsKey($file)) {
            $filesToCreate[$file] = $optionalFilesWithContent[$file]
        }
    }
}

foreach ($filePath in $filesToCreate.Keys) {
    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }

    $folderPath = Split-Path $filePath
    if (-not [string]::IsNullOrWhiteSpace($folderPath) -and -not (Test-Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
    }

    if (-not (Test-Path $filePath)) {
        Write-Host "Creating file: $filePath"
        $filesToCreate[$filePath] | Out-File -FilePath $filePath -Encoding UTF8 -Force
    } else {
        Write-Host "File already exists: $filePath"
    }
}


if (Test-Path "base/settings.py") {
    Remove-Item -Path "base/settings.py"
}

Write-Host "Project setup complete"
