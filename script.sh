# Install Azure cli on macOs
# brew update && brew install azure-cli

# Add azure devops Extension
# az extension add --name azure-devops


# Login to azure account
# az login --allow-no-subscriptions


# Set variables
filename="variables.json"
orgUrl="https://dev.azure.com/luisbonilla345"
projectName="Test Project"


echo "\n----------------------------------------------------------"
echo "\nScript to import variables in JSON format to Azure Devops"
echo "\n----------------------------------------------------------"

# Get file with variables in json format
json=$(cat $filename | jq '.')
# Get array length to count variables-group
length=$(jq length $filename)

for ((i = 0 ; i < $length ; i++)); do
    # Get variable group name
    name=$(echo $json| jq .[$i].name | tr -d '"')

    # Count variables in group
    variableLength=$(jq ".[$i].variables | length" $filename)
    # Get all variable keys/variable names
    keys=$(jq ".[$i].variables | keys" $filename)


    # Check if Variable Group exits in Azure Devops
    group=$(az pipelines variable-group list \
        --org $orgUrl \
        --project "$projectName" | jq ".[] | select(.name==\"$name\")")
    
    # If group exits in azure devops, it's not goint to try 
    # to create it again or create new variables for that group
    if [[ -n $group ]]; then 
        echo "Group $name already exixts"
        continue
    fi


    # Loop into variables in group
    for ((j = 0 ; j < $variableLength ; j++)); do
        # Get current variable Key or Variable name
        currentKey=$(echo $keys | jq ".[$j]" | tr -d '"')
        # Get Varaible information
        variable=$(echo $json | jq .[$i].variables.$currentKey)

        # Get variable value
        value=$(echo $variable | jq .value | tr -d '"')
        # Get variable secret to know if it's a secret variable 
        secret=$(echo $variable | jq .isSecret | tr -d '"')

        # Validate if value equals null in order to not set a value in variable
        if [[ "$value" == "null" ]]; then 
            concat="$currentKey=";
        else
            concat="$currentKey=$value"
        fi

        

        # Check if the first interation i=on $j loop
        # in order to create the variable-group and first variable
        # otherwise it only creates the variable
        if [[ $j == 0 ]]; then
            
            # Create group with first variable
            az pipelines variable-group create \
                --name "$name" \
                --org $orgUrl \
                --project "$projectName" \
                --variables $concat

            # Get ID from created variable group
            variableGroupId=$(az pipelines variable-group list \
                --org $orgUrl \
                --project "$projectName" | jq ".[] | select(.name==\"$name\") | .id")

            # Check if current variable is a secret variable in order to update in correct options
            if [[ "$secret" == "true" ]]; then 
                az pipelines variable-group variable update \
                    --group-id $variableGroupId \
                    --name $currentKey \
                    --org $orgUrl \
                    --project "$projectName" \
                    --secret "$secret"
            fi
        else
            # Check if current variable is a secret variable
            if [[ "$secret" == "true" ]]; then 
                secretVal="true"
            else
                secretVal="false"
            fi

            # Create variable in variable group
            az pipelines variable-group variable create \
                --group-id $variableGroupId \
                --name $currentKey \
                --org $orgUrl \
                --project "$projectName" \
                --value "$value" \
                --secret $secretVal
        fi

    done
done

echo "\nProcess Complete Succesful"