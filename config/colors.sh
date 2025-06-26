# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    colors.sh                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: dlesieur <dlesieur@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/06/26 14:25:21 by dlesieur          #+#    #+#              #
#    Updated: 2025/06/26 14:27:26 by dlesieur         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#!/bin/bash

#check if terminal support colors
if [[ -t 1 ]] & command -v tput > /dev/null 2>&1; then 
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''
    GRAY=''

    BOLD_RED=''
    BOLD_GREEN=''
    BOLD_YELLOW=''
    BOLD_BLUE=''