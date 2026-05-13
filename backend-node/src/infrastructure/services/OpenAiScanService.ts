import { openai } from '../lib/openai.js';
import type { IScanService } from '../../application/services/IScanService.js';
import { ScanImageResponseSchema } from '../../domain/schemas/scanSchemas.js';

export class OpenAIScanService implements IScanService {
  async extractAddressesFromImage(imageBuffer: Buffer) {
    const base64Image = imageBuffer.toString('base64');

    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: `
                Você é um assistente de extração de dados. Analise a imagem fornecida e extraia somente o endereço de entrega, repito, SOMENTE O ENDEREÇO DE ENTREGA.
                Retorne apenas um objeto JSON válido no formato:
                {"addresses": ["endereço1", "endereço2"]}
              `,
            },
            {
              type: 'image_url',
              image_url: {
                url: `data:image/jpeg;base64,${base64Image}`,
              },
            },
          ],
        },
      ],
      max_tokens: 1000,
      response_format: { type: "json_object" },
    });

    const content = response.choices[0]?.message?.content;

    if (!content) {
      throw new Error('A resposta da IA está vazia ou em formato inválido.');
    }

    try {
      const parsedJson = JSON.parse(content);
      return parsedJson;
    } catch (e) {
      throw new Error('Não foi possível fazer o parse do JSON retornado pela IA.');
    }
  }
}