using System;
using System.Windows.Forms;

namespace PoPilotAddin
{
    public partial class TextInputForm : Form
    {
        public string UserInput { get; private set; }
        public string OllamaURL { get; private set; }

        public TextInputForm()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            UserInput = textBox1.Text;
            OllamaURL = textBox2.Text;
            DialogResult = DialogResult.OK;
            Close();
        }

        private void button2_Click(object sender, EventArgs e)
        {
            DialogResult = DialogResult.Cancel;
            Close();
        }
    }
}
