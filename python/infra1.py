import openpyxl
import os

# Specify the path to the Excel file
excel_file_path = '/home/ansibleadm/python/Infra1.xlsx'
sheet_name = 'config'  # Change this to your actual sheet name

# Open the Excel workbook
workbook = openpyxl.load_workbook(excel_file_path)

# Select the sheet by name
sheet = workbook[sheet_name]

# Read data from Excel
aws_region = sheet['C2'].value
instance_type = sheet['C3'].value
instance_name = sheet['C4'].value
#key_name = sheet['C5'].value
ami_id = sheet['C6'].value

# Close the workbook
workbook.close()

# Set Terraform variables using environment variables
os.environ["TF_VAR_aws_region"] = aws_region
os.environ["TF_VAR_instance_type"] = instance_type
os.environ["TF_VAR_instance_name"] = instance_name
#os.environ["TF_VAR_key_name"] = key_name
os.environ["TF_VAR_ami_id"] = ami_id
print(ami_id)

# Run Terraform script
os.system("terraform init")
os.system("terraform plan")
os.system("terraform apply --auto-approve")
