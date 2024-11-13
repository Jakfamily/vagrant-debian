#!/bin/bash

# Fonction pour créer une nouvelle VM
create_vm() {
    # Naviguer vers le répertoire vagrant-vm
    vagrant_vm_dir="vagrant-vm"
    mkdir -p "$vagrant_vm_dir" && cd "$vagrant_vm_dir" || { echo "Échec de l'accès au répertoire $vagrant_vm_dir."; return; }

    # Choisir Debian comme système d'exploitation
    if ! vagrant box list | grep -q "debian/bookworm64"; then
        echo -e "\e[1;33mLa boîte 'debian/bookworm64' n'est pas installée. Installation en cours...\e[0m"
        vagrant box add debian/bookworm64
    else
        echo -e "\e[1;32mLa boîte 'debian/bookworm64' est déjà installée.\e[0m"
    fi
    box_name="debian/bookworm64"

    # Demander le nom du répertoire à créer
    while true; do
        echo -e "\e[1;36mNom du répertoire pour la VM : \e[0m"
        read vm_dir
        if [[ -d "$vm_dir" ]]; then
            echo -e "\e[1;31mLe répertoire '$vm_dir' existe déjà. Veuillez en choisir un autre.\e[0m"
        else
            mkdir "$vm_dir" && cd "$vm_dir"
            break
        fi
    done

    # Demander le nom de la VM
    while true; do
        echo -e "\e[1;36mNom de la VM : \e[0m"
        read vm_name
        if [[ -z "$vm_name" ]]; then
            echo -e "\e[1;31mLe nom de la VM ne peut pas être vide. Veuillez entrer un nom valide.\e[0m"
        else
            break
        fi
    done

    # Demander si une interface graphique est nécessaire
    while true; do
        echo -e "\e[1;36mSouhaitez-vous une interface graphique (GUI) de VirtualBox ? [y/n] : \e[0m"
        read gui_choice
        if [[ "$gui_choice" =~ ^[Yy]$ ]]; then
            gui_config="true"
            break
        elif [[ "$gui_choice" =~ ^[Nn]$ ]]; then
            gui_config="false"
            break
        else
            echo -e "\e[1;31mVeuillez répondre par y ou n.\e[0m"
        fi
    done

    # Demander adresse publique ou privée
    while true; do
        echo -e "\e[1;36mSouhaitez-vous une adresse IP publique ou privée ? (1)public : (2)private : \e[0m"
        read ip_choice
        case $ip_choice in
            1)
                while true; do
                    echo -e "\e[1;36mAdresse IP publique : \e[0m"
                    read ip_address
                    if [[ "$ip_address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        network_config="config.vm.network 'public_network', ip: '$ip_address'"
                        break
                    else
                        echo -e "\e[1;31mAdresse IP invalide. Veuillez entrer une adresse valide.\e[0m"
                    fi
                done
                break
                ;;
            2)
                network_config="config.vm.network 'private_network', type: 'dhcp'"
                break
                ;;
            *)
                echo -e "\e[1;31mOption invalide. Veuillez entrer 1 ou 2.\e[0m"
                ;;
        esac
    done

    # Configuration du provider
    echo -e "\e[1;36mChoisissez le provider : \e[0m"
    select provider in "virtualbox" "vmware_desktop" "hyper-v"; do
        case $provider in
            virtualbox|vmware_desktop)
                echo -e "\e[1;32mVous avez choisi $provider\e[0m"
                break
                ;;
            *)
                echo -e "\e[1;31mOption invalide. Veuillez choisir 1, 2 ou 3.\e[0m"
                ;;
        esac
    done

    # Configuration de la mémoire
    while true; do
        echo -e "\e[1;36mQuantité de mémoire (ex: 1024, 2048, 4096) : \e[0m"
        read memory
        if [[ "$memory" =~ ^[0-9]+$ ]]; then
            break
        else
            echo -e "\e[1;31mVeuillez entrer un nombre valide.\e[0m"
        fi
    done

    # Configuration du nombre de CPU
    while true; do
        echo -e "\e[1;36mNombre de CPU (ex: 1, 2, 4) : \e[0m"
        read cpu
        if [[ "$cpu" =~ ^[0-9]+$ ]]; then
            break
        else
            echo -e "\e[1;31mVeuillez entrer un nombre valide.\e[0m"
        fi
    done

    # Demander un nom d'utilisateur et un mot de passe pour l'utilisateur
    while true; do
        echo -e "\e[1;36mNom d'utilisateur à créer : \e[0m"
        read username
        if [[ -z "$username" ]]; then
            echo -e "\e[1;31mLe nom d'utilisateur ne peut pas être vide.\e[0m"
        else
            break
        fi
    done

    while true; do
        echo -e "\e[1;36mMot de passe pour $username : \e[0m"
        read -sp "" password
        echo
        if [[ -z "$password" ]]; then
            echo -e "\e[1;31mLe mot de passe ne peut pas être vide.\e[0m"
        else
            break
        fi
    done

    # Demander si l'utilisateur veut installer XFCE4
    while true; do
        echo -e "\e[1;36mSouhaitez-vous installer XFCE4 ? [y/n] : \e[0m"
        read xfce_choice
        case $xfce_choice in
            [Yy]* )
                xfce_install="true"
                break
                ;;
            [Nn]* )
                xfce_install="false"
                break
                ;;
            * )
                echo -e "\e[1;31mVeuillez répondre par y ou n\e[0m"
                ;;
        esac
    done

    # Création du fichier Vagrantfile
    cat > Vagrantfile << EOF
Vagrant.configure("2") do |config|
  config.vm.box = "$box_name"
  config.vm.hostname = "$vm_name"
  config.vm.provider "$provider" do |vb|
    vb.memory = "$memory"
    vb.cpus = "$cpu"
    vb.gui = $gui_config
  end
  $network_config

  # Provisionner la VM pour installer les Guest Additions et XFCE4
  config.vm.provision "shell", inline: <<-SHELL
    # Ajouter un utilisateur personnalisé
    sudo useradd -m -s /bin/bash $username
    echo "$username:$password" | sudo chpasswd
    sudo usermod -aG sudo $username

    # Installation de XFCE4 si l'utilisateur a choisi 'y'
    if [ "$xfce_install" == "true" ]; then
      echo "Installation de XFCE4..."
      sudo apt-get update
      sudo apt-get install -y xfce4 xfce4-goodies
    fi

    sleep 60
    sudo systemctl reboot

  SHELL
end
EOF

    # lancer la vm avec vagrant
    vagrant up

    # Fin du script
    echo -e "\e[1;32mLe script est terminé.\e[0m"

    # Demander si l'utilisateur souhaite lancer la VM
    while true; do
        echo -e "\e[1;36mSouhaitez-vous lancer la VM ? [y/n] : \e[0m"
        read choice
        case $choice in
            [Yy]* )
                cd $vm_dir && vagrant ssh
                break
                ;;
            [Nn]* )
                echo -e "\e[1;33mPassage de l'étape de lancement de la VM...\e[0m"
                break
                ;;
            * )
                echo -e "\e[1;31mVeuillez répondre par y ou n\e[0m"
                ;;
        esac
    done
}

# Fonction pour afficher un menu sympa
show_menu() {
    clear
    echo -e "\e[1;34m====================================\e[0m"
    echo -e "\e[1;32m       Menu Principal\e[0m"
    echo -e "\e[1;34m====================================\e[0m"
    echo -e "\n1. Créer une nouvelle VM"
    echo -e "2. Quitter\n"
    echo -e "\e[1;33mChoisissez une option [1/2] : \e[0m"
}

# Menu principal
while true; do
    show_menu
    read -p "" choice

    case $choice in
        1) create_vm ;;
        2) echo -e "\e[1;31mSortie du script.\e[0m" && exit 0 ;;
        *) echo -e "\e[1;31mOption invalide. Essayez à nouveau.\e[0m" ;;
    esac
done
