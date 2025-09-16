## -------------------------------
##
## Install libraries
## 
## Purpose: 
## 
## This file installs all required packages for crosswalk using the package "renv". 
## 
## Authors:  
##      Sean Bock, Abt Global
##      Teagan Goforth, Abt Global
##
## -------------------------------

if(!require("renv", character.only = TRUE)){ # installing renv package if not already
  install.packages("renv", repos = "http://cran.us.r-project.org")
}

required_packages <- unique(renv::dependencies()$Package) # determining required packages used in project


# Loop through each package and install if not already installed.
for (package in required_packages) {
  if (!require(package, character.only = TRUE)) {
    print(paste("Package", package, "not found. Installing package!"))
    install.packages(package, repos = "http://cran.us.r-project.org")
    require(package, character.only = TRUE)
  }
}

# Check if all packages have been installed
all_installed <- all(sapply(required_packages, function(pkg) pkg %in% loadedNamespaces()))

if(all_installed) {
  print("All required packages are installed.")
}