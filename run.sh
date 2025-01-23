#!/bin/bash

# Define color codes for better styling
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RED="\e[31m"
BLUE="\e[34m"
RESET="\e[0m"
WHITE="\e[97m"

# Function to display a loading spinner
loading_spinner() {
    while :; do
        for i in '/' '-' '\' '|'; do
            echo -ne "\r${CYAN}Please wait... ${i} ${RESET}"
            sleep 0.2
        done
    done
}

# Function to run the spinner and handle background tasks
run_spinner() {
    loading_spinner &
    spinner_pid=$!
    sleep 5  # Adjust sleep time based on your task duration
    kill $spinner_pid
    wait $spinner_pid 2>/dev/null
}

# Detect the system environment
detect_os() {
    OS=""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        OS="Windows (Cygwin)"
    elif [[ "$OSTYPE" == "msys" ]]; then
        OS="Windows (MinGW)"
    elif [[ -n "$TERMUX_VERSION" ]]; then
        OS="Termux"
    else
        OS="Unknown"
    fi
    echo $OS
}

# Prompt user for botToken update in the config file
echo -e "${MAGENTA}Please enter your bot token: ${RESET}"
read botToken
if [ -z "$botToken" ]; then
    echo -e "${RED}Bot token cannot be empty! Exiting...${RESET}"
    exit 1
fi
sed -i "s|botToken: \"[^\"]*\"|botToken: \"$botToken\"|" config.js
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Bot token updated successfully!${RESET}"
else
    echo -e "${RED}Failed to update bot token! Exiting...${RESET}"
    exit 1
fi

# Ask user if they want to use port forwarding
echo -e "${CYAN}Do you want to use port forwarding (y/n)? ${RESET}"
read usePortForwarding

if [[ "$usePortForwarding" == "y" || "$usePortForwarding" == "Y" ]]; then
    OS=$(detect_os)  # Fetch the OS
    echo -e "${CYAN}Detected OS: $OS${RESET}"

    # Check if SSH is installed
    if ! command -v ssh &> /dev/null; then
        echo -e "${YELLOW}SSH is not installed. Installing now...${RESET}"
        run_spinner &  # Start the spinner in the background
        
        case "$OS" in
            "Linux")
                sudo apt update && sudo apt install -y openssh-client
                ;;
            "macOS")
                echo -e "${YELLOW}SSH is usually pre-installed on macOS.${RESET}"
                ;;
            "Termux")
                pkg install openssh
                ;;
            *)
                echo -e "${YELLOW}Unknown OS: SSH installation skipped.${RESET}"
                ;;
        esac
        
        echo -e "${GREEN}SSH installation completed!${RESET}"
    else
        echo -e "${GREEN}SSH is already installed.${RESET}"
    fi

    # Run SSH port forwarding in the background
    echo -e "${CYAN}Running port forwarding via serveo...${RESET}"
    ssh -R 80:localhost:5000 serveo.net &
    ssh_pid=$!
    run_spinner &  # Start the spinner in the background
    sleep 5
    kill $spinner_pid
    echo -e "${GREEN}Port forwarding established!${RESET}"

    # Ask for port forwarding URL
    echo -e "${MAGENTA}Please enter the URL from serveo: ${RESET}"
    read portForwardingURL
    sed -i "s|hostURL: \"[^\"]*\"|hostURL: \"$portForwardingURL\"|" config.js
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Host URL updated successfully!${RESET}"
    else
        echo -e "${RED}Failed to update Host URL! Exiting...${RESET}"
        exit 1
    fi
else
    # If user does not want port forwarding, prompt for hostURL directly
    echo -e "${CYAN}Please enter your host URL: ${RESET}"
    read hostURL
    sed -i "s|hostURL: \"[^\"]*\"|hostURL: \"$hostURL\"|" config.js
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Host URL updated successfully!${RESET}"
    else
        echo -e "${RED}Failed to update Host URL! Exiting...${RESET}"
        exit 1
    fi
fi

# Function to check and install Node.js and npm
echo -e "${CYAN}Checking if Node.js and npm are installed...${RESET}"

install_node_npm() {
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo -e "${YELLOW}Node.js or npm is not installed. Installing now...${RESET}"
        
        run_spinner &  # Start spinner in the background
        
        case "$OS" in
            "Linux")
                sudo apt update && sudo apt install -y nodejs npm
                ;;
            "macOS")
                brew install node
                ;;
            "Termux")
                pkg install -y nodejs
                ;;
            *)
                echo -e "${RED}Unknown OS: Installation skipped.${RESET}"
                kill $spinner_pid
                exit 1
                ;;
        esac
        
        kill $spinner_pid  # Stop spinner after installation
        
        # Verify installation
        if command -v node &> /dev/null && command -v npm &> /dev/null; then
            echo -e "${GREEN}Node.js and npm installation completed successfully!${RESET}"
        else
            echo -e "${RED}Installation failed. Please install manually.${RESET}"
            exit 1
        fi
    else
        echo -e "${GREEN}Node.js and npm are already installed.${RESET}"
    fi
}

install_node_npm  # Ensure Node.js and npm are installed before proceeding

# Install npm dependencies
echo -e "${YELLOW}Installing npm packages...${RESET}"
if ! npm install; then
    echo -e "${RED}npm install failed. Exiting...${RESET}"
    exit 1
fi
echo -e "${GREEN}npm packages installed successfully!${RESET}"

# Run the application
echo -e "${GREEN}Starting the application...${RESET}"
npm start
