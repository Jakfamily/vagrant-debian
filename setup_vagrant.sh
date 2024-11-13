#!/bin/bash

# Fonction pour créer une nouvelle VM
create_vm() {
    # Naviguer vers le répertoire vagrant-vm
    vagrant_vm_dir="vagrant-vm"
    mkdir -p "$vagrant_vm_dir" && cd "$vagrant_vm_dir" || { echo "Échec de l'accès au répertoire $vagrant_vm_dir."; return; }

    # Choisir Debian comme système d'exploitation
    if ! vagrant box list | grep -q "debian/bookworm64"; then
        echo "La boîte 'debian/bookworm64' n'est pas installée. Installation en cours..."
        vagrant box add debian/bookworm64
    else
        echo "La boîte 'debian/bookworm64' est déjà installée."
    fi
    box_name="debian/bookworm64"

    # Demander le nom du répertoire à créer
    while true; do
        read -p "Nom du répertoire pour la VM : " vm_dir
        if [[ -d "$vm_dir" ]]; then
            echo "Le répertoire '$vm_dir' existe déjà. Veuillez en choisir un autre."
        else
            mkdir "$vm_dir" && cd "$vm_dir"
            break
        fi
    done

    # Demander le nom de la VM
    while true; do
        read -p "Nom de la VM : " vm_name
        if [[ -z "$vm_name" ]]; then
            echo "Le nom de la VM ne peut pas être vide. Veuillez entrer un nom valide."
        else
            break
        fi
    done

    # Demander si une interface graphique est nécessaire
    while true; do
        read -p "Souhaitez-vous une interface graphique (GUI) de VirtualBox ? [y/n] : " gui_choice
        if [[ "$gui_choice" =~ ^[Yy]$ ]]; then
            gui_config="true"
            break
        elif [[ "$gui_choice" =~ ^[Nn]$ ]]; then
            gui_config="false"
            break
        else
            echo "Veuillez répondre par y ou n."
        fi
    done

    # Demander adresse publique ou privée
    while true; do
        read -p "Souhaitez-vous une adresse IP publique ou privée ? (1)public : (2)private : " ip_choice
        case $ip_choice in
            1)
                while true; do
                    read -p "Adresse IP publique : " ip_address
                    if [[ "$ip_address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        network_config="config.vm.network 'public_network', ip: '$ip_address'"
                        break
                    else
                        echo "Adresse IP invalide. Veuillez entrer une adresse valide."
                    fi
                done
                break
                ;;
            2)
                network_config="config.vm.network 'private_network', type: 'dhcp'"
                break
                ;;
            *)
                echo "Option invalide. Veuillez entrer 1 ou 2."
                ;;
        esac
    done

    # Configuration du provider
    echo "Choisissez le provider :"
    select provider in "virtualbox" "vmware_desktop" "hyper-v"; do
        case $provider in
            virtualbox|vmware_desktop)
                echo "Vous avez choisi $provider"
                break
                ;;
            *)
                echo "Option invalide. Veuillez choisir 1, 2 ou 3."
                ;;
        esac
    done

    # Configuration de la mémoire
    while true; do
        read -p "Quantité de mémoire (ex: 1024, 2048, 4096) : " memory
        if [[ "$memory" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Veuillez entrer un nombre valide."
        fi
    done

    # Configuration du nombre de CPU
    while true; do
        read -p "Nombre de CPU (ex: 1, 2, 4) : " cpu
        if [[ "$cpu" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Veuillez entrer un nombre valide."
        fi
    done

    # Demander un nom d'utilisateur et un mot de passe pour l'utilisateur
    while true; do
        read -p "Nom d'utilisateur à créer : " username
        if [[ -z "$username" ]]; then
            echo "Le nom d'utilisateur ne peut pas être vide."
        else
            break
        fi
    done

    while true; do
        read -sp "Mot de passe pour $username : " password
        echo
        if [[ -z "$password" ]]; then
            echo "Le mot de passe ne peut pas être vide."
        else
            break
        fi
    done

    # Demander si l'utilisateur veut installer XFCE4
    while true; do
        read -p "Souhaitez-vous installer XFCE4 ? [y/n] : " xfce_choice
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
                echo "Veuillez répondre par y ou n"
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
    echo "Le script est terminé."

    # Demander si l'utilisateur souhaite lancer la VM
    while true; do
        read -p "Souhaitez-vous lancer la VM ? [y/n] : " choice
        case $choice in
            [Yy]* )
                cd $vm_dir && vagrant ssh
                break
                ;;
            [Nn]* )
                echo "Passage de l'étape de lancement de la VM..."
                break
                ;;
            * )
                echo "Veuillez répondre par y ou n"
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
